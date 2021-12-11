DFX_HOME ?= $$HOME/.cache/dfinity/versions/0.8.0
MOC ?= $(DFX_HOME)/moc
MOC_FLAGS += --package base "$(DFX_HOME)/base/" 
BUILD ?= build
DIDC ?= didc

$(BUILD)/ledger.wasm: src/*.mo
	mkdir -p $(BUILD)
	$(MOC) $(MOC_FLAGS) -o $@ -c src/Ledger.mo

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
	# We need an unreleased version of DIDC to be able to check subtyping
	# between an actor class and an actor.
	# $(DIDC) check $(BUILD)/ledger.generated.did ledger.did

