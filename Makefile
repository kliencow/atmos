# Atmos Management Makefile
# Focuses on native systemd deployment for Linux (e.g. Raspberry Pi)

.PHONY: build test fmt vet lint help \
        install install-service install-stack \
        config-influx config-grafana add-sensor remove-sensor \
        status vacuum delete-data clean

# --- Variables ---
VERSION=v1.0.0
BINARY_NAME=atmos
SERVICE_TEMPLATE=atmos@.service
INSTALL_PATH=/usr/local/bin
SYSTEMD_PATH=/etc/systemd/system

# --- Standard Targets ---
help:
	@echo "Atmos Management - Usage:"
	@echo "  make build           - Build the Go binary (VERSION=$(VERSION))"
	@echo "  make test            - Run unit tests"
	@echo ""
	@echo "Setup Targets (Run in order):"
	@echo "  make install-stack   - 1. Install InfluxDB, Grafana, and service templates"
	@echo "  make config-influx   - 2. One-click Influx setup (INFLUX_USER=name INFLUX_PASS=pass)"
	@echo "  make config-grafana  - 3. Sync dashboard with Grafana (GRAFANA_PASS=admin_pass)"
	@echo "  make add-sensor      - 4. Register a sensor (NAME=room [IP=... or SERIAL=...])"
	@echo "  make remove-sensor   - Remove a sensor and its configuration (NAME=room)"
	@echo ""
	@echo "Maintenance Targets:"
	@echo "  make status          - Check health status of all components"
	@echo "  make vacuum          - Auto-clean spikes based on .env thresholds (DAYS=7)"
	@echo "  make delete-data     - Wipe specific time range (START=... STOP=...)"
	@echo "  make install-atmos   - Rebuild and reinstall the atmos binary"
	@echo "  make clean           - Remove binary and build artifacts"

build: fmt vet
	go build -ldflags "-X github.com/kliencow/atmos/cmd.Version=$(VERSION)" -o $(BINARY_NAME) ./cmd/atmos

test:
	go test -v ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

lint:
	@if command -v staticcheck > /dev/null; then \
		staticcheck ./...; \
	else \
		echo "staticcheck not found, skipping. Install it with: go install honnef.co/go/tools/cmd/staticcheck@latest"; \
	fi

# --- Installation & Setup ---
install-stack:
	@echo "Refreshing sudo credentials..."
	@sudo -v
	$(MAKE) install-influx
	$(MAKE) install-grafana
	$(MAKE) install-provisioning
	$(MAKE) install-service
	@echo ""
	@echo "--- Bare Metal Installation Complete! ---"
	@echo "Next Steps:"
	@echo "1. Run 'make config-influx INFLUX_USER=admin INFLUX_PASS=password'"
	@echo "2. Run 'make config-grafana GRAFANA_PASS=admin'"
	@echo "3. Run 'make add-sensor NAME=living_room IP=192.168.1.50'"
	@echo "----------------------------------------"

install-influx:
	bash scripts/install_influx.sh

install-grafana:
	bash scripts/install_grafana.sh

install-provisioning:
	@echo "Provisioning Grafana..."
	sudo mkdir -p /etc/grafana/provisioning/dashboards
	sudo mkdir -p /etc/grafana/provisioning/datasources
	sudo mkdir -p /var/lib/grafana/dashboards
	sudo cp deploy/grafana/dashboards.yaml /etc/grafana/provisioning/dashboards/dashboards.yaml
	sudo cp deploy/grafana/datasources/influxdb.yaml /etc/grafana/provisioning/datasources/influxdb.yaml
	sudo cp deploy/grafana/dashboards/air_quality.json /var/lib/grafana/dashboards/
	sudo chown -R grafana:grafana /var/lib/grafana/dashboards
	sudo systemctl restart grafana-server

install: build
	@echo "Stopping any running atmos services..."
	@-sudo systemctl stop "atmos@*"
	@sudo cp $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Restarting enabled atmos services..."
	@# This finds all enabled atmos@ services and starts them
	@-systemctl list-unit-files "atmos@*" | grep enabled | cut -d' ' -f1 | xargs -r sudo systemctl start


install-service: install
	@echo "Installing systemd service template..."
	sudo cp deploy/systemd/$(SERVICE_TEMPLATE) $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo sed -i "s|User=USER_PLACEHOLDER|User=$(USER)|" $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo sed -i "s|DIR_PLACEHOLDER|$(PWD)|g" $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo systemctl daemon-reload
	@echo "Service template installed."

config-influx:
	@if [ -z "$(INFLUX_USER)" ] || [ -z "$(INFLUX_PASS)" ]; then \
		echo "Error: INFLUX_USER and INFLUX_PASS are required."; \
		echo "Usage: make config-influx INFLUX_USER=name INFLUX_PASS=password"; \
		exit 1; \
	fi
	bash scripts/config_influx.sh $(INFLUX_USER) $(INFLUX_PASS)

config-grafana:
	@if [ -z "$(GRAFANA_PASS)" ]; then \
		echo "Error: GRAFANA_PASS is required."; \
		echo "Usage: make config-grafana GRAFANA_PASS=your_password"; \
		exit 1; \
	fi
	GRAFANA_PASS=$(GRAFANA_PASS) bash scripts/config_grafana.sh

# --- Sensor Management ---
add-sensor:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME is required."; \
		echo "Usage: make add-sensor NAME=room_name [IP=... SERIAL=...]"; \
		exit 1; \
	fi
	@echo "Adding sensor: $(NAME)"
	@sudo mkdir -p /etc/atmos
	@if [ ! -z "$(SERIAL)" ] || [ ! -z "$(IP)" ] || [ ! -f /etc/atmos/$(NAME).env ]; then \
		echo "# Identity flags for atmos@$(NAME).service" | sudo tee /etc/atmos/$(NAME).env > /dev/null; \
		if [ ! -z "$(SERIAL)" ]; then \
			echo "SENSOR_SERIAL=$(SERIAL)" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
			echo "# SENSOR_IP=" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
		elif [ ! -z "$(IP)" ]; then \
			echo "SENSOR_IP=$(IP)" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
			echo "# SENSOR_SERIAL=" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
		else \
			echo "# Provide either SENSOR_SERIAL (mDNS) or SENSOR_IP" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
			echo "SENSOR_SERIAL=CHANGE_ME" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
			echo "# SENSOR_IP=192.168.1.100" | sudo tee -a /etc/atmos/$(NAME).env > /dev/null; \
		fi; \
		echo "Configuration saved to /etc/atmos/$(NAME).env"; \
	fi
	@if [ ! -z "$(SERIAL)" ] || [ ! -z "$(IP)" ] || grep -qv "CHANGE_ME" /etc/atmos/$(NAME).env 2>/dev/null; then \
		sudo systemctl enable --now atmos@$(NAME) > /dev/null 2>&1; \
		sudo systemctl restart atmos@$(NAME); \
		echo "Sensor atmos@$(NAME) is active. Check logs: journalctl -u atmos@$(NAME) -f"; \
	else \
		echo "Template created at /etc/atmos/$(NAME).env. Please edit it, then run:"; \
		echo "  sudo systemctl enable --now atmos@$(NAME)"; \
	fi

remove-sensor:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME is required."; \
		echo "Usage: make remove-sensor NAME=room_name"; \
		exit 1; \
	fi
	@echo "Removing sensor: $(NAME)"
	-sudo systemctl disable --now atmos@$(NAME)
	-sudo rm -f /etc/atmos/$(NAME).env
	@echo "Sensor $(NAME) removed."

# --- Maintenance & Cleanup ---
install-atmos: install

status:
	@echo "--- Atmos Stack Status ---"
	@if command -v $(BINARY_NAME) > /dev/null; then \
		echo "Atmos Binary: $$(atmos --version)"; \
	else \
		echo "Atmos Binary: NOT INSTALLED"; \
	fi
	@echo -n "InfluxDB: "
	@curl -s http://localhost:8086/health | grep -q '"status":"pass"' && echo "PASS (Healthy)" || echo "FAIL (Down)"
	@echo -n "Grafana:  "
	@curl -sL --fail http://localhost:3000/api/health | grep -qi "ok" && echo "PASS (Healthy)" || echo "FAIL (Down)"
	@echo ""
	@echo "--- Active Sensors ---"
	@systemctl list-units "atmos@*" --no-legend --all | while read -r unit load active sub rest; do \
		name=$$(echo $$unit | sed -e 's/atmos@//' -e 's/\.service//'); \
		config="/etc/atmos/$$name.env"; \
		if [ -f "$$config" ]; then \
			ip=$$(grep "^SENSOR_IP=" "$$config" | cut -d= -f2); \
			ser=$$(grep "^SENSOR_SERIAL=" "$$config" | cut -d= -f2); \
			addr="$$ip"; \
			[ ! -z "$$ser" ] && addr="airgradient_$$ser.local"; \
			reach="[Unreachable]"; \
			[ ! -z "$$addr" ] && curl -s -m 2 -o /dev/null --fail "http://$$addr/measures/current" && reach="[Reachable]"; \
			details=""; \
			[ ! -z "$$ip" ] && details="IP: $$ip"; \
			[ ! -z "$$ser" ] && [ ! -z "$$details" ] && details="$$details, "; \
			[ ! -z "$$ser" ] && details="$${details}Serial: $$ser"; \
			printf "  %-18s %-10s %-10s %-14s %s\n" "[$$name]" "$$active" "$$sub" "$$reach" "$$details"; \
		fi; \
	done || echo "  No active sensors found."

vacuum:
	bash scripts/vacuum.sh $(DAYS)

delete-data:
	@if [ -z "$(START)" ] || [ -z "$(STOP)" ]; then \
		echo "Error: START and STOP are required. Usage: make delete-data START=... STOP=..."; \
		exit 1; \
	fi
	influx delete --bucket air_quality --org atmos --start $(START) --stop $(STOP) $(if $(PREDICATE),--predicate '$(PREDICATE)')

clean:
	rm -f $(BINARY_NAME)
