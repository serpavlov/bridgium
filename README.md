# Bridgium
Selenium-compatible server for testing Android apps.

Works under uiautomator.

## Main feature of this project is:

When you test Android application with uiatomator-based frameworks, you will see, that all accessibility services not working. You can't test app functionality related to accessibility. One solution to this problem is to memorize the elements in the test code and then  pass the test script and don't use uiautomator.

## Install
- Set Android SDK tools and build-tools to PATH (adb and aapt needed)
- Install gems argv, nokogiri, jsonrpc-client
- Clone
- Run ruby server.rb
