# Figure out the containing dir of this Makefile
OVERLAY_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Declare custom installation commands
define custom_prepare_commands

		@echo "Overwriting wil6210 driver from custom source in $(OVERLAY_DIR)"
		$(CP) $(OVERLAY_DIR)/wil6210/* $(PKG_BUILD_DIR)/drivers/net/wireless/ath/wil6210/

endef

# Append custom commands to install recipe,
# and make sure to include a newline to avoid syntax error
Build/Prepare += $(newline)$(custom_prepare_commands)
