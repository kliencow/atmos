package cmd

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/spf13/cobra"
)

var (
	influxURL    string
	influxToken  string
	influxOrg    string
	influxBucket string
	debug        bool
)

var rootCmd = &cobra.Command{
	Use:   "atmos",
	Short: "Atmos polls AirGradient sensors and sends data to time-series backends",
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		if err := godotenv.Load(); err != nil {
			if !os.IsNotExist(err) {
				log.Printf("Error loading .env file: %v", err)
			}
		}
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() {
	if err := rootCmd.ExecuteContext(context.Background()); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&influxURL, "influx-url", getEnv("INFLUX_URL", ""), "InfluxDB URL (e.g. http://localhost:8086)")
	rootCmd.PersistentFlags().StringVar(&influxToken, "influx-token", getEnv("INFLUX_TOKEN", ""), "InfluxDB Token")
	rootCmd.PersistentFlags().StringVar(&influxOrg, "influx-org", getEnv("INFLUX_ORG", ""), "InfluxDB Organization")
	rootCmd.PersistentFlags().StringVar(&influxBucket, "influx-bucket", getEnv("INFLUX_BUCKET", ""), "InfluxDB Bucket")
	rootCmd.PersistentFlags().BoolVar(&debug, "debug", false, "Enable debug logging")
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
