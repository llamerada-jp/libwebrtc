package cmd

import (
	"fmt"
	"os"
	"path"
	"runtime"

	"github.com/colonio/libwebrtc/pkg/build"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var isDebug bool
var targetArch string

var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "build libwebrtc",
	Long:  "TBD",
	RunE: func(cmd *cobra.Command, args []string) error {
		viper.SetConfigFile(path.Join("configs", fmt.Sprintf("%s_%s.yml", runtime.GOOS, targetArch)))
		if err := viper.ReadInConfig(); err != nil {
			return err
		}
		var config build.Config
		if err := viper.Unmarshal(&config); err != nil {
			return err
		}
		if err := build.Execute(&config, targetArch, isDebug); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return nil
	},
}

func init() {
	buildCmd.PersistentFlags().BoolVar(&isDebug, "is-debug", false, "enable debug flag")
	buildCmd.PersistentFlags().StringVar(&targetArch, "arch", getDefaultArch(), "target CPU architecture")
	rootCmd.AddCommand(buildCmd)
}

func getDefaultArch() string {
	var archMap = map[string]string{
		"386": "i386",
	}

	arch, ok := archMap[runtime.GOARCH]
	if !ok {
		arch = runtime.GOARCH
	}

	return arch
}
