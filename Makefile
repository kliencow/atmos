# Atmos Management Makefile
# Focuses on native systemd deployment for Linux (e.g. Raspberry Pi)

.PHONY: build test fmt vet lint help \
        install install-service setup-system init-auth \
        setup-sensor setup-dashboard status \
        vacuum clean-data clean

# --- Variables ---
BINARY_NAME=atmos
SERVICE_TEMPLATE=atmos@.service
INSTALL_PATH=/usr/local/bin
SYSTEMD_PATH=/etc/systemd/system

# --- Standard Targets ---
help:
	@echo "Atmos Management - Usage:"
	@echo "  make build           - Build the Go binary"
	@echo "  make test            - Run unit tests"
	@echo ""
	@echo "Setup Targets (Run in order):"
	@echo "  make setup-system    - 1. Install InfluxDB, Grafana, and service templates"
	@echo "  make init-auth       - 2. One-click Influx setup (USER=name PASS=pass)"
	@echo "  make setup-sensor    - 3. Register a sensor (NAME=room [IP=... or SERIAL=...])"
	@echo "  make setup-dashboard - 4. Sync the latest dashboard via Grafana API"
	@echo ""
	@echo "Maintenance Targets:"
	@echo "  make status          - Check health status of all components"
	@echo "  make vacuum          - Auto-clean spikes based on .env thresholds (DAYS=7)"
	@echo "  make clean-data      - Delete data (START=... STOP=...)"
	@echo "  make clean           - Remove binary and build artifacts"

build: fmt vet
	go build -o $(BINARY_NAME) ./cmd/atmos

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
setup-system: install-influx install-grafana install-provisioning install-service
	@echo ""
	@echo "--- Bare Metal Installation Complete! ---"
	@echo "Next Steps:"
	@echo "1. Run 'make init-auth USER=admin PASS=password' to initialize your database."
	@echo "2. Run 'make setup-sensor NAME=living_room IP=192.168.1.50' to configure your first sensor."
	@echo "3. Run 'make setup-dashboard' to finalize the UI."
	@echo "----------------------------------------"

install-influx:
	bash scripts/setup_influx.sh

install-grafana:
	bash scripts/setup_grafana.sh

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
	sudo cp $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)

install-service: install
	@echo "Installing systemd service template..."
	sudo cp deploy/systemd/$(SERVICE_TEMPLATE) $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo sed -i "s|User=USER_PLACEHOLDER|User=$(USER)|" $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo sed -i "s|DIR_PLACEHOLDER|$(PWD)|g" $(SYSTEMD_PATH)/$(SERVICE_TEMPLATE)
	sudo systemctl daemon-reload
	@echo "Service template installed."

init-auth:
	@if [ -z "$(USER)" ] || [ -z "$(PASS)" ]; then echo "Error: USER and PASS are required. Usage: make init-auth USER=name PASS=password"; exit 1; fi
	bash scripts/init_influx.sh $(USER) $(PASS)

# --- Sensor Management ---
setup-sensor:
	@if [ -z "$(NAME)" ]; then echo "Error: NAME is required. Usage: make setup-sensor NAME=room_name [IP=192.168.1.10] [SERIAL=12345]"; exit 1; fi
	@echo "Setting up sensor for: $(NAME)"
	sudo mkdir -p /etc/atmos
	@if [ ! -f /etc/atmos/$(NAME).env ]; then \
		echo "# Identity flags for atmos@$(NAME).service" | sudo tee /etc/atmos/$(NAME).env; \
		if [ ! -z "$(SERIAL)" ]; then \
			echo "SENSOR_SERIAL=$(SERIAL)" | sudo tee -a /etc/atmos/$(NAME).env; \
			echo "# SENSOR_IP=" | sudo tee -a /etc/atmos/$(NAME).env; \
		elif [ ! -z "$(IP)" ]; then \
			echo "SENSOR_IP=$(IP)" | sudo tee -a /etc/atmos/$(NAME).env; \
			echo "# SENSOR_SERIAL=" | sudo tee -a /etc/atmos/$(NAME).env; \
		else \
			echo "# Provide either SENSOR_SERIAL (mDNS) or SENSOR_IP" | sudo tee -a /etc/atmos/$(NAME).env; \
			echo "SENSOR_SERIAL=CHANGE_ME" | sudo tee -a /etc/atmos/$(NAME).env; \
			echo "# SENSOR_IP=192.168.1.100" | sudo tee -a /etc/atmos/$(NAME).env; \
		fi; \
		echo "Created /etc/atmos/$(NAME).env"; \
	fi
	@if [ ! -z "$(SERIAL)" ] || [ ! -z "$(IP)" ]; then \
		sudo systemctl enable --now atmos@$(NAME); \
		echo "Sensor atmos@$(NAME) started. Check logs with: journalctl -u atmos@$(NAME) -f"; \
	else \
		echo "Template created at /etc/atmos/$(NAME).env. Please edit it, then run:"; \
		echo "  sudo systemctl enable --now atmos@$(NAME)"; \
	fi

setup-dashboard:
	bash scripts/import_grafana.sh

# --- Maintenance & Cleanup ---
status:
	@echo "--- Atmos Stack Status ---"
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

clean-data:
	@if [ -z "$(START)" ] || [ -z "$(STOP)" ]; then \
		echo "Error: START and STOP are required. Usage: make clean-data START=... STOP=..."; \
		exit 1; \
	fi
	influx delete --bucket air_quality --org atmos --start $(START) --stop $(STOP) $(if $(PREDICATE),--predicate '$(PREDICATE)')

clean:
	rm -f $(BINARY_NAME)
