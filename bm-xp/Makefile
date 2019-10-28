PYTHON ?= python
PORT ?= 8037

start_server:
	@# see https://stackoverflow.com/questions/3739327/launching-a-website-via-windows-commandline
	@echo "Starting server at url https://localhost:$(PORT)"
	$(PYTHON) -m http.server $(PORT) 2>&1 &
