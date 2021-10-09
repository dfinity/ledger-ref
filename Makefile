DFX_HOME ?= $$HOME/.cache/dfinity/versions/0.8.0
MOC ?= $(DFX_HOME)/moc
MOC_FLAGS += --package base "$(DFX_HOME)/base/" 

ledger.wasm: src/Ledger.mo src/Account.mo
	$(MOC) $(MOC_FLAGS) -o $@ -c $<

.PHONY: test
test:
	@set -e; for f in src/*Test*.mo ; do \
		echo "Running tests in $$(basename $$f) ..."; \
		$(MOC) $(MOC_FLAGS) -r "$$f"; \
		echo "OK"; \
	done
