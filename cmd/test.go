package cmd

import (
	"fmt"
	"os"

	"github.com/colonio/libwebrtc/pkg/test"
	"github.com/spf13/cobra"
)

var testArch string

var testCmd = &cobra.Command{
	Use:   "test",
	Short: "test libwebrtc",
	Long:  "TBD",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := test.Execute(testArch); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return nil
	},
}

func init() {
	testCmd.PersistentFlags().StringVar(&testArch, "arch", "amd64", "target CPU architecture")
	rootCmd.AddCommand(testCmd)
}
