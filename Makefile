ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/docs

DOCS = docs/Kernel/System/RocketChat.html docs/Kernel/System/RocketChat/Util.html docs/Kernel/GenericInterface/Invoker/RocketChat/Lookup.html

FRAGMENTS = docs/fragment-index.html docs/fragment-head.html docs/fragment-foot.html

docs: docs/index.html

docs/index.html: $(FRAGMENTS)
	cat docs/{fragment-head.html,fragment-index.html,fragment-foot.html} > $@

docs/fragment-index.html: $(DOCS)
	echo $? \
	  | tr ' ' "\n" \
	  | sed 's|^docs/||' \
	  | sed -E 's|^(.*)$$|<li><a href="\1">\1</a></li>|' \
	  > docs/fragment-index.html

docs/%.html: %.pm
	@mkdir -p $(dir $@)
	pod2html --css=$(ROOT_DIR)/style.css \
		--podroot=./ \
		--podpath=./ \
		--htmlroot=$(ROOT_DIR)/\
		--infile=$? \
		--outfile=$@

clean:
	rm -f  docs/{index.html,fragment-index.html}
	rm -rf docs/Kernel

.PHONY: clean
