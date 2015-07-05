boards=de5 nfsume
projects=dtp sonic blueswitch

targets=$(foreach b,$(boards),$(foreach p,$(projects),$(patsubst %,%.$b,$p)))

print-%:
	@echo '$*=$($*)'

.PHONY: $(targets)

$(targets):
	make -C $(firstword $(subst ., ,$@)) gen.$(lastword $(subst ., ,$@))
	make -C $(firstword $(subst ., ,$@)) build.$(lastword $(subst ., ,$@))
