# Odysee MVP (UI Branch)

This is the UI branch. This only contains a stripped version of the Roku app for planning and integration purposes.
The code will not make any HTTP requests and will use placeholders. This is to allow planning endpoints for upcoming features.
UI Elements will be defined identically to the production app and this branch will (hopefully) eventually be referenced as a dependency by the indev branch.

This should hopefully allow UI contributions without breaking existing code.

## Roku App Build Instructions
https://sdkdocs-archive.roku.com/Loading-and-Running-Your-Application_3737091.html

## How to Sideload an App on Roku
To sideload an app onto your Roku device, follow the simple step-by-step instructions below.

1. Press Home (x3) + Up (x2) + Right + Left + Right + Left + Right on your Roku's remote control to put your device into Developer Mode.
1. Make a note of the on-screen IP address.
1. Select I Agree on the SDK License page.
1. Create a password.
1. Enter the previously-noted IP address into your browser.
1. Click on Upload.
1. Select the ZIP file of the channel you want to install.
1. Click on Install.