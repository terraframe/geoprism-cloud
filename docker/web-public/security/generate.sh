#!/bin/bash
# This script is more for documentation right now than anything else so don't be surprised if you can't run it commandline without problems.

# Exit on errors
set -e


keytool -genkey -alias geoprism -keystore geoprism.ks -keyalg RSA -dname "CN=www.geoprism.net, OU=Geoprism, O=TerraFrame, L=Denver, ST=CO, C=US" -storepass changeit -keypass changeit

# Create a certificate signing request (CSR)
keytool -certreq -alias geoprism -keystore geoprism.ks -keyalg rsa -file geoprism.csr


# Install the intermediate into the keystore
$JAVA_HOME/bin/keytool -importcert -alias intermediate -trustcacerts -file ./IntermediateCA.crt -keystore ./geoprism.ks -storepass changeit

# Install the geoprism certificate into the keystore
$JAVA_HOME/bin/keytool -importcert -alias geoprism -trustcacerts -file ./geoprism.crt -keystore ./geoprism.ks -storepass changeit
