build-AWSRubySDKLayer:
	bundle config set --local path $(ARTIFACTS_DIR)
	bundle install
	rm -rf $(ARTIFACTS_DIR)/ruby/2.7.0/cache && rm -rf $(ARTIFACTS_DIR)/ruby/2.7.0/bin
	mkdir $(ARTIFACTS_DIR)/ruby/gems
	mv $(ARTIFACTS_DIR)/ruby/2.7.0 $(ARTIFACTS_DIR)/ruby/gems
	mkdir $(ARTIFACTS_DIR)/ruby/lib
	cp *.rb $(ARTIFACTS_DIR)/ruby/lib