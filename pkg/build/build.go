package build

import (
	"bufio"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path"
	"regexp"
	"strings"
	"text/template"
	"time"
)

//go:embed buildinfo.template
var BuildInfoTemplate string

const (
	DepotToolsURL     = "https://chromium.googlesource.com/chromium/tools/depot_tools.git"
	ChromeInfoURL     = "https://omahaproxy.appspot.com/all.json"
	WebrtcInfoURL     = "https://raw.githubusercontent.com/chromium/chromium/%s/DEPS"
	BuildInfoFilename = "libwebrtc_buildinfo.txt"
)

type Config struct {
	ChromeOsStr       string
	BuildDepsOpts     []string
	SysrootArch       *string
	GnOpts            []string
	BuildTargets      []string
	NinjaFile         string
	NinjaTarget       string
	ExcludeFiles      []string
	Headers           []string
	HeadersWithSubdir []string
}

type chromeInfo struct {
	Os       string `json:os`
	Versions []struct {
		BranchCommit   string `json:"branch_commit"`
		Channel        string `json:"channel"`
		CurrentVersion string `json:"current_version"`
	} `json:"versions"`
}

type build struct {
	// directories
	optDir  string
	tmpDir  string
	workDir string

	TargetOS string
	// configurations from command line
	TargetArch string
	isDebug    bool

	// configurations read from file
	config *Config

	// chrome infomations
	ChromeVersion  string
	ChromeCommitID string
	WebrtcCommitID string
}

func command(path, name string, args ...string) {
	fmt.Printf("\x1b[36m%s\x1b[0m$ %s", path, name)
	for _, v := range args {
		fmt.Print(" ", v)
	}
	fmt.Println()

	cmd := exec.Command(name, args...)
	cmd.Dir = path
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Errorf("Run", err)
		os.Exit(1)
	}
}

func commandStdin(path, input, name string, args ...string) {
	fmt.Printf("\x1b[36m%s\x1b[0m$ %s", path, name)
	for _, v := range args {
		fmt.Print(" ", v)
	}
	fmt.Println()

	cmd := exec.Command(name, args...)
	cmd.Dir = path
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		fmt.Fprint(os.Stderr, err)
		os.Exit(1)
	}
	io.WriteString(stdin, input)
	stdin.Close()
	if err := cmd.Run(); err != nil {
		fmt.Fprint(os.Stderr, err)
		os.Exit(1)
	}
}

func unlink(path string) {
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		if err := os.RemoveAll(path); err != nil {
			fmt.Fprint(os.Stderr, err)
			os.Exit(1)
		}
	}
}

func Execute(config *Config, targetOS, targetArch string, isDebug bool) error {
	build := &build{
		config:     config,
		TargetOS:   targetOS,
		TargetArch: targetArch,
		isDebug:    isDebug,
	}

	if err := build.makeDirs(); err != nil {
		return err
	}
	if err := build.setupDepotTools(); err != nil {
		return err
	}
	if err := build.getChromeInfo(); err != nil {
		return err
	}
	if err := build.getWebrtcInfo(); err != nil {
		return err
	}
	if err := build.build(); err != nil {
		return err
	}

	switch targetOS {
	case "linux":
		if err := build.makeLibLinux(); err != nil {
			return err
		}
	case "macos":
		if err := build.makeLibMacos(); err != nil {
			return err
		}
	}
	if err := build.collectHeaders(); err != nil {
		return err
	}
	if err := build.generateBuildInfo(); err != nil {
		return err
	}
	if err := build.makeArchive(); err != nil {
		return err
	}
	return nil
}

func (b *build) makeDirs() error {
	pwd, _ := os.Getwd()
	b.optDir = path.Join(pwd, "opt")
	b.workDir = path.Join(b.optDir, fmt.Sprintf("%s_%s", b.TargetOS, b.TargetArch))
	b.tmpDir = path.Join(b.workDir, "tmp")

	unlink(path.Join(b.workDir, "include"))
	if err := os.MkdirAll(path.Join(b.workDir, "include"), os.ModePerm); err != nil {
		return err
	}
	unlink(path.Join(b.workDir, "lib"))
	if err := os.MkdirAll(path.Join(b.workDir, "lib"), os.ModePerm); err != nil {
		return err
	}
	unlink(b.tmpDir)
	if err := os.MkdirAll(b.tmpDir, os.ModePerm); err != nil {
		return err
	}
	return nil
}

func (b *build) setupDepotTools() error {
	depotToolsPath := path.Join(b.optDir, "depot_tools")

	if _, err := os.Stat(depotToolsPath); os.IsNotExist(err) {
		command("opt", "git", "clone", DepotToolsURL)

	} else {
		command(depotToolsPath, "git", "checkout", "master")
		command(depotToolsPath, "git", "pull")
	}

	path := os.Getenv("PATH")
	if err := os.Setenv("PATH", fmt.Sprintf("%s:%s", depotToolsPath, path)); err != nil {
		return err
	}

	return nil
}

func (b *build) getChromeInfo() error {
	httpClient := http.Client{
		Timeout: 60 * time.Second,
	}
	res, err := httpClient.Get(ChromeInfoURL)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("http status code was not ok", ChromeInfoURL, res.Status)
	}
	var chromeInfos []chromeInfo
	if err := json.NewDecoder(res.Body).Decode(&chromeInfos); err != nil {
		return err
	}
	for _, info := range chromeInfos {
		if info.Os == b.config.ChromeOsStr {
			for _, v := range info.Versions {
				if v.Channel == "stable" {
					b.ChromeCommitID = v.BranchCommit
					b.ChromeVersion = v.CurrentVersion
					return nil
				}
			}
		}
	}

	return fmt.Errorf("the infomation of chrome for specified platform was not found %v", b.config.ChromeOsStr)
}

func (b *build) getWebrtcInfo() error {
	httpClient := http.Client{
		Timeout: 60 * time.Second,
	}
	res, err := httpClient.Get(fmt.Sprintf(WebrtcInfoURL, b.ChromeCommitID))
	if err != nil {
		return err
	}
	defer res.Body.Close()

	scanner := bufio.NewScanner(res.Body)
	rep := regexp.MustCompile(`webrtc_git.*src\.git.*@.*'([a-f0-9]+)'`)
	for scanner.Scan() {
		group := rep.FindStringSubmatch(scanner.Text())
		if len(group) == 2 {
			b.WebrtcCommitID = group[1]
			return nil
		}
	}

	return fmt.Errorf("the infomation of WebRTC was not found %v", b.ChromeCommitID)
}

func (b *build) build() error {
	if _, err := os.Stat(path.Join(b.workDir, ".gclient")); os.IsNotExist(err) {
		if err := os.MkdirAll(b.workDir, os.ModePerm); err != nil {
			return err
		}
		command(b.workDir, "fetch", "--nohooks", "webrtc")
	}

	sd := path.Join(b.workDir, "src")
	command(sd, "git", "fetch", "origin")
	// command(sd, "git", "clean", "-df")
	command(sd, "git", "checkout", b.WebrtcCommitID)
	if b.TargetOS == "linux" {
		depOpts := b.config.BuildDepsOpts
		depOpts = append(depOpts, "--no-prompt")
		command(sd, "./build/install-build-deps.sh", depOpts...)
		if b.config.SysrootArch != nil {
			command(sd, "./build/linux/sysroot_scripts/install-sysroot.py", "--arch="+*b.config.SysrootArch)
		}
	}
	command(sd, "gclient", "sync", "-D")

	opts := b.config.GnOpts
	if b.isDebug {
		opts = append(opts, "is_debug=true")
	} else {
		opts = append(opts, "is_debug=false")
	}
	if b.config.SysrootArch != nil {
		opts = append(opts, "use_sysroot=true")
	} else {
		opts = append(opts, "use_sysroot=false")
	}
	command(sd, "gn", "gen", "out/Default", "--args="+strings.Join(opts, " "))

	for _, buildTarget := range b.config.BuildTargets {
		command(sd, "ninja", "-C", path.Join("out", "Default"), buildTarget)
	}

	return nil
}

func (b *build) makeLibLinux() error {
	fp, err := os.Open(path.Join(b.workDir, "src", "out", "Default", b.config.NinjaFile))
	if err != nil {
		return err
	}
	defer fp.Close()

	linkedFiles := make([]string, 0)
	scanner := bufio.NewScanner(fp)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, b.config.NinjaTarget) {
			linkedFiles = append(linkedFiles, strings.Split(line, " ")...)
		}
	}
	oFiles := make([]string, 0)
	script := "create " + path.Join(b.workDir, "lib", "libwebrtc.a\n")
NEXT_FILE:
	for _, file := range linkedFiles {
		for _, ex := range b.config.ExcludeFiles {
			if strings.Contains(file, ex) {
				continue NEXT_FILE
			}
		}
		if strings.HasSuffix(file, ".o") {
			oFiles = append(oFiles, path.Join("src", "out", "Default", file))
		}
		if strings.HasSuffix(file, ".a") {
			script = script + "addlib " + path.Join("src", "out", "Default", file) + "\n"
		}
	}
	libtmp := path.Join(b.tmpDir, "libmywebrtc.a")
	args := append([]string{"cr", libtmp}, oFiles...)
	command(b.workDir, "ar", args...)
	script = script + "addlib " + libtmp + "\nsave\nend"
	unlink(path.Join(b.workDir, "libwebrtc.a"))
	commandStdin(b.workDir, script, "ar", "-M")
	return nil
}

func (b *build) makeLibMacos() error {
	fp, err := os.Open(path.Join(b.workDir, "src", "out", "Default", b.config.NinjaFile))
	if err != nil {
		return err
	}
	defer fp.Close()

	linkedFiles := make([]string, 0)
	scanner := bufio.NewScanner(fp)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, b.config.NinjaTarget) {
			linkedFiles = append(linkedFiles, strings.Split(line, " ")...)
		}
	}
	oFiles := make([]string, 0)
	aFiles := make([]string, 0)
NEXT_FILE:
	for _, file := range linkedFiles {
		if strings.HasSuffix(file, "_objc.a") {
			continue
		}
		for _, ex := range b.config.ExcludeFiles {
			if strings.Contains(file, ex) {
				continue NEXT_FILE
			}
		}
		if strings.HasSuffix(file, ".o") {
			oFiles = append(oFiles, path.Join("src", "out", "Default", file))
		}
		if strings.HasSuffix(file, ".a") {
			aFiles = append(aFiles, path.Join("src", "out", "Default", file))
		}
	}
	libtmp := path.Join(b.tmpDir, "libmywebrtc.a")
	args := append([]string{"cr", libtmp}, oFiles...)
	command(b.workDir, "ar", args...)
	aFiles = append(aFiles, libtmp)
	args = append([]string{"-o", path.Join(b.workDir, "lib", "libwebrtc.a")}, aFiles...)
	command(b.workDir, "libtool", args...)
	return nil
}

func (b *build) collectHeaders() error {
	for _, p := range b.config.Headers {
		dst := path.Join(b.workDir, "include", p)
		src := path.Join(b.workDir, "src", p)
		if err := os.MkdirAll(dst, os.ModePerm); err != nil {
			return err
		}
		files, err := ioutil.ReadDir(src)
		if err != nil {
			return err
		}
		for _, file := range files {
			if strings.HasSuffix(file.Name(), ".h") {
				command(b.workDir, "cp", path.Join(src, file.Name()), dst)
			}
		}
	}
	for _, p := range b.config.HeadersWithSubdir {
		command(path.Join(b.workDir, "src"),
			"find", p, "-name", "*.h", "-exec",
			"rsync", "-R", "{}", path.Join(b.workDir, "include"), ";")
	}

	return nil
}

func (b *build) generateBuildInfo() error {
	tmpl, err := template.New("buildinfo").Parse(BuildInfoTemplate)
	if err != nil {
		return err
	}
	f, err := os.Create(path.Join(b.workDir, BuildInfoFilename))
	if err != nil {
		return err
	}
	defer f.Close()

	fw := bufio.NewWriter(f)
	err = tmpl.Execute(fw, *b)
	if err != nil {
		return err
	}
	return fw.Flush()
}

func (b *build) makeArchive() error {
	if b.TargetOS == "linux" {
		fname := fmt.Sprintf("libwebrtc-%s-linux-%s.tar.gz", b.ChromeVersion, b.TargetArch)
		command(b.workDir, "tar", "cvzf", fname, "include", "lib", BuildInfoFilename)
	}
	if b.TargetOS == "macos" {
		fname := fmt.Sprintf("libwebrtc-%s-macos-%s.zip", b.ChromeVersion, b.TargetArch)
		command(b.workDir, "zip", "-r", fname, "include", "lib", BuildInfoFilename)
	}
	return nil
}
