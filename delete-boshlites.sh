#!/bin/bash

set -e

cd delete-boshlites
bundle
bundle exec ruby delete-boshlites.rb
