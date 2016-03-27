##
# NOTICE
#
# Copyright (c) 2016 David C Vernet and Matthew J Perron. All rights reserved.
#
# Unless otherwise noted, all of the material in this file is Copyright (c) 2016
# by David C Vernet and Matthew J Perron. All rights reserved. No part of this file
# may be reproduced, published, distributed, displayed, performed, copied,
# stored, modified, transmitted or otherwise used or viewed by anyone other
# than the authors (David C Vernet and Matthew J Perron),
# for either public or private use.
#
# No part of this file may be modified, changed, exploited, or in any way
# used for derivative works or offered for sale without the express
# written permission of the authors.
#
# This file has been modified from lightweight-java-profiler
# (https://github.com/dcapwell/lightweight-java-profiler). See APACHE_LICENSE for
# a copy of the license that was included with that original work.
#


SHELL:=/bin/bash
UNAME:=$(shell uname | tr '[A-Z]' '[a-z]')
PWD:=$(shell pwd)

BITS?=64
ifeq ($(UNAME), darwin)
  READLINK_ARGS:=""
  PLATFORM_WARNINGS:=-Weverything -Wno-c++98-compat-pedantic -Wno-padded \
	-Wno-missing-prototypes
  PLATFORM_COPTS:=-std=c++11 -stdlib=libc++ -DTARGET_RT_MAC_CFM=0
  HEADERS:=Headers
  CC=clang++
  LDFLAGS=-Wl,-fatal_warnings -Wl,-std=c++11 -Wl,-stdlib=libc++
  ifeq ($(BITS), 64)
    # Why is this not $!$#@ defined?
    PLATFORM_COPTS+=-D__LP64__=1
  endif
else ifeq ($(UNAME), linux)
  READLINK_ARGS:="-f"
  PLATFORM_COPTS:=-mfpmath=sse -std=gnu++0x
  PLATFORM_WARNINGS:=-Wframe-larger-than=16384 -Wno-unused-but-set-variable \
    -Wunused-but-set-parameter -Wvla -Wno-conversion-null \
    -Wno-builtin-macro-redefined
  HEADERS:=include
  CC=g++
  LDFLAGS=-Wl,--fatal-warnings
endif

JAVA_HOME := $(shell \
	[[ -n "$${JAVA_HOME}" ]] || \
	  JAVA_HOME=$$(dirname $$(readlink $(READLINK_ARGS) $$(which java)))/../; \
	[[ "$${JAVA_HOME}" =~ /jre/ ]] && JAVA_HOME=$${JAVA_HOME}/../; \
	[[ -n "$${JAVA_HOME}" ]] || (echo "Cannot find JAVA_HOME" && exit) ; \
	echo $${JAVA_HOME})
AGENT=liblagent.so
LIBS=-ldl -lpthread
BUILD_DIR ?= $(shell mkdir build-$(BITS) 2> /dev/null ; echo build-$(BITS))
SRC_DIR:=${PWD}/src
OPT?=-O3
GLOBAL_WARNINGS= -Wformat-security -Wno-char-subscripts \
	-Wno-sign-compare -Wno-strict-overflow -Wwrite-strings -Wnon-virtual-dtor \
	-Woverloaded-virtual
GLOBAL_COPTS=-fdiagnostics-show-option -fno-exceptions \
	-fno-omit-frame-pointer -fno-strict-aliasing -funsigned-char \
	-fno-asynchronous-unwind-tables -m$(BITS) -msse2 -g \
	-D__STDC_FORMAT_MACROS
COPTS:=$(PLATFORM_COPTS) $(GLOBAL_COPTS) $(PLATFORM_WARNINGS) \
	$(GLOBAL_WARNINGS) $(OPT)

INCLUDES=-I$(JAVA_HOME)/$(HEADERS) -I$(JAVA_HOME)/$(HEADERS)/$(UNAME) 


# LDFLAGS+=-Wl,--export-dynamic-symbol=Agent_OnLoad

SOURCES=$(wildcard $(SRC_DIR)/*.cc)
_OBJECTS=$(SOURCES:.cc=.pic.o)
OBJECTS = $(patsubst $(SRC_DIR)/%,$(BUILD_DIR)/%,$(_OBJECTS))

$(BUILD_DIR)/%.pic.o: $(SRC_DIR)/%.cc
	$(CC) $(INCLUDES) $(COPTS) -Fvisibility=hidden -fPIC -c $< -o $@

$(AGENT): $(OBJECTS)
	$(CC) $(COPTS) -shared -o $(BUILD_DIR)/$(AGENT) \
	  -Bsymbolic $(OBJECTS) $(LIBS)

all: $(AGENT)

run:
	java -agentpath:./build-64/liblagent.so test.Test

java:
	javac test/*.java

clean:
	rm -rf $(BUILD_DIR)/*

kill:
	pkill -9 java
