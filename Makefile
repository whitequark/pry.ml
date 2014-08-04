build:
	ocaml pkg/build.ml native=true native-dynlink=true

test: build
	ocamlbuild -use-ocamlfind -classic-display \
						 ./src_test/test_inj.byte ./src_test/test_read.byte

clean:
	ocamlbuild -clean

.PHONY: build test doc clean

gh-pages: doc
	git clone `git config --get remote.origin.url` .gh-pages --reference .
	git -C .gh-pages checkout --orphan gh-pages
	git -C .gh-pages reset
	git -C .gh-pages clean -dxf
	cp -t .gh-pages/ api.docdir/*
	git -C .gh-pages add .
	git -C .gh-pages commit -m "Update Pages"
	git -C .gh-pages push origin gh-pages -f
	rm -rf .gh-pages

release:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make release VERSION=1.0.0"; exit 1; fi
	git checkout -B release
	sed -i 's/%%VERSION%%/$(VERSION)/' pkg/META
	git add .
	git commit -m "Prepare for release."
	git tag -a v$(VERSION) -m "Version $(VERSION)"
	git checkout @{-1}
	git branch -D release
	git push origin v$(VERSION)

.PHONY: gh-pages release
