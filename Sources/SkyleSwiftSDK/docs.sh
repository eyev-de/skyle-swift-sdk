#!/bin/sh

#  docs.sh
#  SkyleSwiftSDK
#
#  Created by Kw on 23.07.20.
#  

jazzy \
--min-acl internal \
--module SkyleSwiftSDK \
--swift-build-tool spm \
--build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5
