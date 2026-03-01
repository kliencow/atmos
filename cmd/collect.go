package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/kliencow/atmos/internal/influx"
	"github.com/kliencow/atmos/internal/sensor"
	"github.com/kliencow/atmos/internal/sys"
	"github.com/spf13/cobra"
)

var (
	sensorIP    string
	serial      string
	location    string
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

		// Use targetAddr as default location if not specified
		loc := location
		if loc == "" {
			loc = targetAddr
		}

		var influxClient *influx.Client
		if influxURL != "" {
			influxClient = influx.NewClient(influxURL, influxToken, influxOrg, influxBucket)
			defer influxClient.Close()
		}

		if !noHeaders {
			fmt.Println("Timestamp,VOC,NOX,Temp_C,Humidity_Pct,CO2_PPM,PM2.5,Sys_Temp_C")
		}

		if interval <= 0 {
			if err := poll(cmd.Context(), targetAddr, loc, influxClient); err != nil {
				log.Printf("Error: %v", err)
				if exitOnError {
					os.Exit(1)
				}
			}
			return
		}

		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for {
			if err := poll(cmd.Context(), targetAddr, loc, influxClient); err != nil {
				log.Printf("Error: %v", err)
				if exitOnError {
					os.Exit(1)
				}
			}

			select {
			case <-cmd.Context().Done():
				return
			case <-ticker.C:
				continue
			}
		}
	},
}

func init() {
	collectCmd.Flags().StringVar(&sensorIP, "ip", getEnv("SENSOR_IP", ""), "IP address of the sensor")
	collectCmd.Flags().StringVar(&serial, "serial", getEnv("SENSOR_SERIAL", ""), "Serial number (for mDNS)")
	collectCmd.Flags().StringVar(&location, "location", getEnv("SENSOR_LOCATION", ""), "Location name for the sensor (e.g. living_room)")
	collectCmd.Flags().DurationVar(&interval, "interval", 0, "Polling interval (e.g. 1m). If 0, runs once.")
	collectCmd.Flags().BoolVar(&noHeaders, "no-headers", false, "Omit CSV headers")
	collectCmd.Flags().BoolVar(&exitOnError, "exit-on-error", false, "Exit on reading error")
	rootCmd.AddCommand(collectCmd)
}

func poll(ctx context.Context, addr string, location string, client *influx.Client) error {
	data, err := sensor.Fetch(ctx, addr, debug)
	if err != nil {
		return err
	}

	sysTemp, err := sys.GPUTemp()
	if err != nil && debug {
		log.Printf("DEBUG Sys Temp error: %v", err)
	}

	printRow(data, sysTemp)

	if client != nil {
		return client.Write(ctx, location, addr, data, sysTemp)
	}
	return nil
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
