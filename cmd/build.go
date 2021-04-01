package cmd

import (
	"fmt"
	"os"
	"path"
	"runtime"

	"github.com/llamerada-jp/libwebrtc/pkg/build"
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
		targetOS := runtime.GOOS
		if targetOS == "darwin" {
			targetOS = "macos"
		}
		viper.SetConfigFile(path.Join("configs", fmt.Sprintf("%s_%s.yml", targetOS, targetArch)))
		if err := viper.ReadInConfig(); err != nil {
			return err
		}
		var config build.Config
		if err := viper.Unmarshal(&config); err != nil {
			return err
		}
		if err := build.Execute(&config, targetOS, targetArch, isDebug); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return nil
	},
}

func init() {
	buildCmd.PersistentFlags().BoolVar(&isDebug, "is-debug", false, "enable debug flag")
	buildCmd.PersistentFlags().StringVar(&targetArch, "arch", "amd64", "target CPU architecture")
	rootCmd.AddCommand(buildCmd)
}
