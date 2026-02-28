package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/spf13/cobra"
	"github.com/kliencow/atmos/internal/influx"
	"github.com/kliencow/atmos/internal/sensor"
	"github.com/kliencow/atmos/internal/sys"
)

var (
	sensorIP    string
	serial      string
	interval    time.Duration
	noHeaders   bool
	exitOnError bool
)

var collectCmd = &cobra.Command{
	Use:   "collect",
	Short: "Collect data from an AirGradient sensor",
	Run: func(cmd *cobra.Command, args []string) {
		if sensorIP == "" && serial == "" {
			log.Fatal("Error: Either --ip or --serial must be provided.")
		}

		targetAddr := sensorIP
		if serial != "" {
			targetAddr = fmt.Sprintf("airgradient_%s.local", serial)
		}

		var influxClient *influx.Client
		if influxURL != "" {
			influxClient = influx.NewClient(influxURL, influxToken, influxOrg, influxBucket)
			defer influxClient.Close()
		}

		sysTemp, err := sys.GPUTemp()
		if err != nil && debug {
			log.Printf("DEBUG Sys Temp error: %v", err)
		}

		if interval <= 0 {
			if err := runOnce(cmd.Context(), targetAddr, sysTemp, influxClient); err != nil {
				log.Printf("Error: %v", err)
				if exitOnError {
					os.Exit(1)
				}
			}
			return
		}

		runLoop(cmd.Context(), targetAddr, sysTemp, influxClient)
	},
}

func init() {
	collectCmd.Flags().StringVar(&sensorIP, "ip", getEnv("SENSOR_IP", ""), "IP address of the sensor")
	collectCmd.Flags().StringVar(&serial, "serial", getEnv("SENSOR_SERIAL", ""), "Serial number (for mDNS)")
	collectCmd.Flags().DurationVar(&interval, "interval", 0, "Polling interval (e.g. 1m). If 0, runs once.")
	collectCmd.Flags().BoolVar(&noHeaders, "no-headers", false, "Omit CSV headers")
	collectCmd.Flags().BoolVar(&exitOnError, "exit-on-error", false, "Exit on reading error")
	rootCmd.AddCommand(collectCmd)
}

func runOnce(ctx context.Context, addr string, sysTemp *float64, client *influx.Client) error {
	data, err := sensor.Fetch(ctx, addr, debug)
	if err != nil {
		return err
	}

	if !noHeaders {
		fmt.Println("Timestamp,VOC,NOX,Temp_C,Humidity_Pct,CO2_PPM,PM2.5,Sys_Temp_C")
	}

	printRow(data, sysTemp)

	if client != nil {
		return client.Write(ctx, addr, data, sysTemp)
	}
	return nil
}

func runLoop(ctx context.Context, addr string, sysTemp *float64, client *influx.Client) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	if !noHeaders {
		fmt.Println("Timestamp,VOC,NOX,Temp_C,Humidity_Pct,CO2_PPM,PM2.5,Sys_Temp_C")
	}

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			data, err := sensor.Fetch(ctx, addr, debug)
			if err != nil {
				log.Printf("Error: %v", err)
				if exitOnError {
					os.Exit(1)
				}
				continue
			}

			printRow(data, sysTemp)

			if client != nil {
				if err := client.Write(ctx, addr, data, sysTemp); err != nil {
					log.Printf("Influx error: %v", err)
				}
			}
		}
	}
}

func printRow(data sensor.AGData, sysTemp *float64) {
	sysTempStr := "N/A"
	if sysTemp != nil {
		sysTempStr = fmt.Sprintf("%.1f", *sysTemp)
	}

	fmt.Printf("%s,%.0f,%.0f,%.1f,%.1f,%.0f,%.1f,%s\n",
		time.Now().Format(time.RFC3339),
		data.VOC,
		data.NOX,
		data.Temp,
		data.Humidity,
		data.CO2,
		data.PM25,
		sysTempStr,
	)
}
