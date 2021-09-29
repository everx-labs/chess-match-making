MAKEFLAGS += --no-builtin-rules --warn-undefined-variables --no-print-directory
include Makefile.common

SYS:=system
CCH:=$(SYS)/cache

# Contracts
T:=Repo
N:=NSMatchmaker
STATIC:=$T $N

C:=NSMatchmakerClient
P:=Partner
W:=Watcher
USER:=$C $P $W

PCP:=Participant
MM:=Matchmaker
BASE:=$(PCP) $(MM)

O:=$C $P $W

M:=CasualMatchmaker
L:=RatedMatchmaker
G:=Game
SYSTEM:=$M $L $G

TA:=$(STATIC) $(USER) $(SYSTEM)
RKEYS:=$(KEY)/k1.keys

VAL0:=65
DIRS:=$(CCH) $(patsubst %,$(SYS)/%,$(TA)) games out

all: cc

install: dirs cc
	$(TOC) config --url net.ton.dev --async_call=true --balance_in_tons=true

TOOLS_MAJOR_VERSION:=0.50
TOOLS_MINOR_VERSION:=0
TOOLS_VERSION:=$(TOOLS_MAJOR_VERSION).$(TOOLS_MINOR_VERSION)
TOOLS_ARCHIVE:=tools_$(TOOLS_MAJOR_VERSION)_$(UNAME_S).tar.gz
TOOLS_URL:=https\://github.com/tonlabs/TON-Solidity-Compiler/releases/download/$(TOOLS_VERSION)/$(TOOLS_ARCHIVE)
TOOLS_BIN:=$(LIB) $(SOLC) $(LINKER) $(TOC)
$(TOOLS_BIN):
	mkdir -p $(BIN)
	rm -f $(TOOLS_ARCHIVE)
	wget $(TOOLS_URL)
	tar -xzf $(TOOLS_ARCHIVE) -C $(BIN)

tools: $(TOOLS_BIN)
	$(foreach t,$(wordlist 2,4,$^),$t --version;)

sync:
	$(TOC) config --async_call=false
async:
	$(TOC) config --async_call=true

clean:
	$(foreach c,$(TA),rm -f $(SYS)/$c/*.out $(SYS)/$c/*.args $(SYS)/$c/*.res)
$(DIRS):
	mkdir -p $@

$(SYS)/contracts:
	printf "$N 0\n$C 1\n$P 2\n$W 3\n$M 4\n$L 5\n$G 6\n" >$@

DEPLOYED=$(patsubst %,$(BLD)/%.deployed,$(STATIC))

vpath %.sol $(SRC)
vpath %.tvc $(BLD)

dirs: $(DIRS)
	echo $^
cc: $(patsubst %,$(BLD)/%.tvc,$(TA))
	echo $^
deploy: $(DEPLOYED)
	-cat $^

$P.sol $W.sol: $(PCP).sol
$L.sol $M.sol: $(MM).sol
$C.sol: $P.sol

$(BLD)/%.code $(BLD)/%.abi.json: $(SRC)/%.sol
	$(SOLC) $< -o $(BLD)
$(BLD)/%.tvc: $(BLD)/%.code $(BLD)/%.abi.json
	$(LINKER) compile --lib $(LIB) $< -a $(word 2,$^) -o $@
$(BLD)/%.shift: $(BLD)/%.tvc $(BLD)/%.abi.json $(RKEYS)
	$(TOC) genaddr $< $(word 2,$^) --setkey $(word 3,$^) | grep "Raw address:" | sed 's/.* //g' >$@
$(BLD)/%.cargs:
	$(file >$@,{})
$(BLD)/%.deployed: $(BLD)/%.shift $(BLD)/%.tvc $(BLD)/%.abi.json $(RKEYS) $(BLD)/%.cargs
	$(call _pay,$(file < $<),$(VAL0))
	$(TOC) deploy $(word 2,$^) --abi $(word 3,$^) --sign $(word 4,$^) $(word 5,$^) >$@
$(BLD)/%.stateInit: $(BLD)/%.tvc
	$(BASE64) $< >$@

$(SYS)/$N/address:
	echo 0:411fe213ccaa71c9d3883fc9b51947a028fb226eb2bf9168ca6f84f09b806938 >$@
$(SYS)/$T/address:
	echo 0:2ceec47feefcaf0d1f226bce6f6a06b8094eb51b0848d15c68f04152e0c4b371 >$@

$(SYS)/$G/address: $(SYS)/$C/_cgames.out
	mkdir -p $(@D)
	jq -r '._cgames["$F"].gameAddress' <$< >$@

F:=159
F0:=31

_rated=$(if $(shell echo "if ($1 > 127) 1"|bc),rated,)

$(SYS)/flavor:
	echo $F >$@
$(patsubst %,$(SYS)/%/setNSMatchmakerAddress.args,$O): $(SYS)/$N/address
	$(file >$@,$(call _args,addr,$(strip $(file <$<))))
$(SYS)/$C/requestMatchmaker.args:
	$(file >$@,$(call _args,flavor,$F))
$(patsubst %,$(SYS)/%/queryMatchmaker.args,$O):
	$(file >$@,$(call _args,flavor,$F))
$(SYS)/$N/set$LSI.args: $(BLD)/$L.stateInit
	$(file >$@,$(call _args,flavor c,128 $(strip $(file <$<))))
$(SYS)/$N/set$MSI.args: $(BLD)/$M.stateInit
	$(file >$@,$(call _args,flavor c,$F $(strip $(file <$<))))

$(SYS)/$N/setMatchmakerSI.res: $(SYS)/$N/address $(BLD)/$N.abi.json $(SYS)/$N/set$LSI.args  $(SYS)/$N/set$MSI.args
	$(TOC) call $(file <$<) --abi $(word 2,$^) setMatchmakerSI $(word 4,$^)
	$(TOC) call $(file <$<) --abi $(word 2,$^) setMatchmakerSI $(word 3,$^)
$(SYS)/$N/setGameSI.args: $(BLD)/$G.stateInit
	$(file >$@,$(call _args,c,$(strip $(file <$<))))

$(SYS)/$C/cancelRequest.args:
	$(file >$@,$(call _args,flavor,$F))

_cn=$(shell grep -w $* $(SYS)/contracts | cut -d ' ' -f 2)
$(SYS)/$T/updateImage_$M.args: $(SYS)/contracts $(BLD)/$M.stateInit
	$(file >$@,$(call _args,n flavor c,4 $(F0) $(file <$(word 2,$^))))
$(SYS)/$T/updateImage_$L.args: $(SYS)/contracts $(BLD)/$L.stateInit
	$(file >$@,$(call _args,n flavor c,5 $F $(file <$(word 2,$^))))
$(SYS)/$T/updateImage_%.args: $(SYS)/contracts $(BLD)/%.stateInit
	$(file >$@,$(call _args,n flavor c,$(_cn) $F $(file <$(word 2,$^))))

IMAGES:=$(patsubst %,$(SYS)/$T/updateImage_%.res,$N $(USER) $(SYSTEM))

$(SYS)/$T/updateImage_%.res: $(SYS)/$T/address $(BLD)/$T.abi.json $(SYS)/$T/updateImage_%.args
	$(TOC) call $(file <$<) --abi $(word 2,$^) updateImage $(word 3,$^)

upgrade: $(IMAGES)
	echo $^
	rm $(SYS)/$T/_active.out
spawn: $(SYS)/$T/deploy.res
	echo $^

$(SYS)/$C/all: $(SYS)/$T/_active.out
	jq -r '._active[] | select(.kind=="1") .id' <$< >$@
$(SYS)/$P/all: $(SYS)/$T/_active.out
	jq -r '._active[] | select(.kind=="2") .id' <$< >$@
$(SYS)/$W/all: $(SYS)/$T/_active.out
	jq -r '._active[] | select(.kind=="3") .id' <$< >$@

x1: $(SYS)/$T/_active.out $(SYS)/$C/all $(SYS)/$P/all $(SYS)/$W/all
	$(foreach i,$(file <$(word 2,$^)),jq -r '._active | to_entries[] | select(.value.id=="$i") .key' <$< >$(CCH)/$C.$i;)
	$(foreach i,$(file <$(word 3,$^)),jq -r '._active | to_entries[] | select(.value.id=="$i") .key' <$< >$(CCH)/$P.$i;)
	$(foreach i,$(file <$(word 4,$^)),jq -r '._active | to_entries[] | select(.value.id=="$i") .key' <$< >$(CCH)/$W.$i;)

$(SYS)/$N/casual: $(SYS)/$N/flavors
	$(file >$@,) $(foreach i,$(strip $(file <$(word 1,$^))),$(if $(call _rated,$i),,$(file >>$@,$i)))
$(SYS)/$N/rated: $(SYS)/$N/flavors
	$(file >$@,) $(foreach i,$(strip $(file <$(word 1,$^))),$(if $(call _rated,$i),$(file >>$@,$i),))
$(SYS)/$N/flavors: $(SYS)/$N/_dedicated.out $(SYS)/flavor
	jq -r '._dedicated | keys | .[]' <$< >$@
x2: $(SYS)/$N/_makers.out $(SYS)/$N/flavors $(SYS)/$N/casual $(SYS)/$N/rated
	$(foreach i,$(strip $(file <$(word 2,$^))),jq -r '._makers[] | select(.flavor=="$i") .addr' <$< >$(if $(call _rated,$i),$(CCH)/$L.$i,$(CCH)/$M.$i);)
	mkdir -p $(SYS)/$L/$F

$(SYS)/$L/%/_games.out: $(CCH)/$L.%
	$(call _pub,$L,_games) >$@
$(SYS)/$L/%/games: $(SYS)/$L/%/_games.out
	jq -r 'to_entries[] | select(.value.status=="7") .key' <$< >$@
#make grx159
grx%: $(SYS)/$L/%/_games.out $(SYS)/$L/%/games
	$(foreach i,$(strip $(file <$(word 2,$^))),jq -r '.["$i"].addr' <$< >$(CCH)/$G.$*.$i;)

_move=$(call _args,index isWhite alg,$1 true $2),$(call _args,index isWhite alg,$1 false $3)
_arg0="$1":$2
_hex=$(shell echo -n $1 | xxd -p -c 30000)
_pair0=$(call _arg0,$(word 1,$1),$(word 1,$2))$(if $(word 2,$1),$(comma)$(call _pair0,$(wordlist 2,$(words $1),$1),$(wordlist 2,$(words $2),$2)),)
_args0={$(if $(word 1,$1),$(call _pair0,$1,$2),)}
_moves=$(call _move,$(word 1,$1),$(word 2,$1),$(word 3,$1))$(if $(word 4,$1),$(comma)$(call _moves,$(wordlist 4,$(words $1),$1),))

define t-call
$(SYS)/$1/$2.res: $(SYS)/$1/address $(BLD)/$1.abi.json $(SYS)/$1/$2.args
	$(TOC) call $$(file <$$<) --abi $$(word 2,$$^) $$(subst .args,,$$(basename $$(notdir $$(word 3,$$^)))) $$(word 3,$$^)

endef

define t-call-args
$(SYS)/$1/$2.args:
	$$(file >$$@,$$(call _args,$3,$4))

$(SYS)/$1/$2.res: $(SYS)/$1/address $(BLD)/$1.abi.json $(SYS)/$1/$2.args
	$(TOC) call $$(file <$$<) --abi $$(word 2,$$^) $$(subst .args,,$$(basename $$(notdir $$(word 3,$$^)))) $$(word 3,$$^)

c_$2: $(SYS)/$1/$2.res
	echo $$^
endef

define t-run
$(SYS)/$1/$2.out: $(SYS)/$1/address $(BLD)/$1.abi.json
	$(TOC) -j run $$(file <$$<) --abi $$(word 2,$$^) $2 {} >$$@
endef

$(foreach c,$O,$(eval $(call t-call,$c,setNSMatchmakerAddress)))
$(eval $(call t-call,$C,requestMatchmaker))
$(foreach c,$O,$(eval $(call t-call,$c,queryMatchmaker)))
$(eval $(call t-call,$C,cancelRequest))
$(foreach c,$O,$(eval $(call t-call,$c,recordMoves)))

NR:=_makers _dedicated _requests _makersCopy _version _mrCode _mcCode _gameCode _peer
TR:=_counter _meta _images _active _flavor _nsmm
$(foreach c,$(TR),$(eval $(call t-run,$T,$c)))

$(eval $(call t-call-args,$T,setNSMatchmakerAddress,addr,$(file <$(SYS)/$N/address)))
$(eval $(call t-call-args,$T,deploy,flavor,$F))

DDR=$(patsubst %,$(SYS)/$N/%.out,$(NR))
TTR=$(patsubst %,$(SYS)/$T/%.out,$(TR))

IINF=$(patsubst %,infoc.%,$(file <$(SYS)/$C/all)) $(patsubst %,infop.%,$(file <$(SYS)/$P/all)) $(patsubst %,infow.%,$(file <$(SYS)/$W/all))
QMM=$(patsubst %,qmmc.%,$(file <$(SYS)/$C/all)) $(patsubst %,qmmp.%,$(file <$(SYS)/$P/all)) $(patsubst %,qmmw.%,$(file <$(SYS)/$W/all))
RMM=$(patsubst %,rmm.%,$(file <$(SYS)/$N/rated))
_run=$(TOC) -j run $(file <$<) --abi $(BLD)/$1.abi.json
_pub=$(TOC) -j run $(file <$<) --abi $(BLD)/$1.abi.json $2 {} | jq -rj '.$2'
_call=$(TOC) call $(file <$<) --abi $(BLD)/$1.abi.json
info: $(IINF)
	echo $^
infoc.%: $(CCH)/$C.%
	@echo -ne $C $* '\t'
	@$(TOC) account $(file <$<) | grep balance
	@$(call _pub,$C,_cgames)
	@$(call _pub,$C,_matchmakers) | jq -r -c 'keys'
	@$(call _pub,$C,_ratings) | jq -c '.'
	@$(call _pub,$C,_results)
	@$(call _pub,$C,_gameInfo)
infop.%: $(CCH)/$P.%
	@echo -ne $P $* '\t'
	@$(TOC) account $(file <$<) | grep balance
	@$(call _pub,$P,_cgames) | jq -r -c '.?'
	@$(call _pub,$P,_matchmakers) | jq -r -c 'keys'
	@$(call _pub,$P,_results)
	@$(call _pub,$P,_gameInfo)
infow.%: $(CCH)/$W.%
	@echo -ne $W $* '\t'
	@$(TOC) account $(file <$<) | grep balance
	@$(call _pub,$W,_cgames)
	@$(call _pub,$W,_matchmakers) | jq -r -c 'keys'

qmm: $(QMM)
	echo $^
qmmc.%: $(CCH)/$C.%
	@$(call _call,$C) queryMatchmaker '{"flavor":$F}'
qmmp.%: $(CCH)/$P.%
	@$(call _call,$P) queryMatchmaker '{"flavor":$F}'
qmmw.%: $(CCH)/$W.%
	@$(call _call,$W) queryMatchmaker '{"flavor":$F}'
rmm: $(RMM)
	echo $^

MMR:=_entrants _games _pending _needWatching _requestedCount _availableObservers _errorLog
LMR:=$(MMR) _matching

rmm.%: $(CCH)/$L.%
	$(foreach r,$(LMR),$(call _pub,$L,$r);)

# make rqr169
rqr%: $(CCH)/$C.%
	$(file >out/aa,$(call _args,flavor ratingLo ratingHi quota,$F 1400 1700 1))
	$(call _call,$C) requestGame out/aa
# make jgr170
jgr%: $(CCH)/$P.%
	$(call _call,$P) joinGame '{"flavor":$F}'
	rm $(SYS)/$L/$F/_games.out
# make ror171
ror%: $(CCH)/$W.%
	$(call _call,$W) register '{"flavor":$F}'
rsor%: $(CCH)/$W.%
	$(call _call,$W) resign '{"flavor":$F}'
crr%: $(CCH)/$C.%
	$(call _call,$C) cancelRequest '{"flavor":$F}'

_vgr=$(TOC) -j run $(file <$<) --abi $(BLD)/$G.abi.json $1 {} | jq -r '.$1';
VGR:=_writers _maxMove _checkPoint _recs _consensys _errorLog
_gr=$(TOC) -j run $(file <$<) --abi $(BLD)/$G.abi.json
vg%: $(CCH)/$G.$F.%
	@$(foreach r,$(VGR),$(call _vgr,$r))
	$(_gr) viewMatch {} | jq -r '.records'
	$(_gr) errorLog {}

va: $(SYS)/$T/_active.out
	echo $^

reqmm%: $(CCH)/$C.%
	$(call _call,$C) requestMatchmaker '{"flavor":$F}'

# make rmc298 rmp385 rmw343
define t-rm
rm$2%: games/axxx $(CCH)/$1.%
	$$(file >out/bb,$$(call _args0,flavor moves,$F [$$(call _moves,$$(subst ., ,$$(file <$$<)))]))
	$(TOC) call $$(file <$$(word 2,$$^)) --abi $(BLD)/$1.abi.json recordMoves out/bb
endef

$(eval $(call t-rm,$C,c))
$(eval $(call t-rm,$P,p))
$(eval $(call t-rm,$W,w))

# make m0 part=a05
part?=a0
m0:
	rm -f games/axxx
	cp games/$(part) games/axxx

d1: $(TTR) $(DDR)
	echo $^

_code=$(shell $(LINKER) decode --tvc $(word 3,$^) | grep "code:" | cut -d ' ' -f 3)
_idx=$(shell grep $* $(word 2,$^) | cut -d ' ' -f 2)
_imgRepo=$(shell jq -r '._images | .["$(_idx)"]' <$<)
c%: $(SYS)/$T/_images.out $(SYS)/contracts $(BLD)/%.tvc
	echo $(if $(findstring $(_code),$(_imgRepo)),equal,different)

results.%: $(CCH)/$G.$F.%
	$(_gr) viewMatch {} | jq -r '.records[]'

$(SYS)/$N/%.out: $(SYS)/$N/address $(BLD)/$N.abi.json
	$(TOC) -j run $(file <$<) --abi $(word 2,$^) $* {} >$@

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)
