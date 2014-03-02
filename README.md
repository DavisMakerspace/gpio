# GPIO for Ruby

This provides a basic Ruby class to wrap the sysfs interface to the Linux GPIOs.

Also provided is a fake GPIO class with an identical interface to allow for testing even when GPIOs are not present.

A minitest is provided that will test both the real and fake interfaces.
