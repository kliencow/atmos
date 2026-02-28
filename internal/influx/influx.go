package influx

import (
	"context"
	"fmt"
	"time"

	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/api"
	"github.com/kliencow/atmos/internal/sensor"
)

// Client handles writing data to InfluxDB
type Client struct {
	client   influxdb2.Client
	writeAPI api.WriteAPIBlocking
}

// NewClient returns a new InfluxDB client
func NewClient(url, token, org, bucket string) *Client {
	c := influxdb2.NewClient(url, token)
	return &Client{
		client:   c,
		writeAPI: c.WriteAPIBlocking(org, bucket),
	}
}

// Close closes the InfluxDB client
func (c *Client) Close() {
	c.client.Close()
}

// Write records sensor data and optional system temperature to InfluxDB
func (c *Client) Write(ctx context.Context, ip string, data sensor.AGData, sysTemp *float64) error {
	fields := map[string]interface{}{
		"voc":      data.VOC,
		"nox":      data.NOX,
		"temp":     data.Temp,
		"humidity": data.Humidity,
		"co2":      data.CO2,
		"pm25":     data.PM25,
	}
	if sysTemp != nil {
		fields["sys_temp"] = *sysTemp
	}

	p := influxdb2.NewPoint("air_quality",
		map[string]string{"sensor": ip},
		fields,
		time.Now())

	if err := c.writeAPI.WritePoint(ctx, p); err != nil {
		return fmt.Errorf("influx write error: %w", err)
	}
	return nil
}
