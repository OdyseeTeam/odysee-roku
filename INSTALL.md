## Roku App Build Instructions
https://sdkdocs-archive.roku.com/Loading-and-Running-Your-Application_3737091.html

## How to Sideload an App on Roku
To sideload an app onto your Roku device, follow the simple step-by-step instructions below.

1.Using your Roku remote, enter the following button sequence: 
> :house: :house: :house: + :arrow_up_small: :arrow_up_small: + :arrow_forward: :arrow_backward: + :arrow_forward:  :arrow_backward: + :arrow_forward:
2. Make a note of the on-screen IP address or check your roku's IP address on your router.
3. Select I Agree on the SDK License page.
4. Create a password.
5. Enter the previously-noted IP address into your browser.
6. Click on Upload.
7. Select the ZIP file of the channel you want to install.
8. Click on Install.

## Developer Instructions
If you want to debug, clone this repository and go to roku-main-channel folder. You can see the core files such as components, images, etc.

If you want to sideload, just zip your directory, but exclude the out folder. If you want to excecute it via IDE, check the appropriate plugin/export settings on your IDE.