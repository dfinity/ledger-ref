DFX_HOME ?= $$HOME/.cache/dfinity/versions/0.8.0
MOC ?= $(DFX_HOME)/moc
MOC_FLAGS += --package base "$(DFX_HOME)/base/" 
BUILD ?= build
DIDC ?= didc

$(BUILD)/ledger.wasm: src/*.mo
	mkdir -p $(BUILD)
	$(MOC) $(MOC_FLAGS) -o $@ -c $<

.PHONY: test
test:
	@set -e; for f in src/*Test*.mo ; do \
		echo "Running tests in $$(basename $$f) ..."; \
		$(MOC) $(MOC_FLAGS) -r "$$f"; \
		echo "OK"; \
	done

.PHONY: check
check:
	mkdir -p $(BUILD)
	$(MOC) $(MOC_FLAGS) --idl src/Ledger.mo -o $(BUILD)/ledger.generated.did
	$(DIDC) check $(BUILD)/ledger.generated.did ledger.did

