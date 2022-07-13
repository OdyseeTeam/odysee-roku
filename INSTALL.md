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

## Alternative Instructions (far easier for practical use if you use VSCode/VSCodium)
### **(Harder setup but easier to debug w/more information)**
1. Perform above sideload steps 1 - 4
2. Install the [VSCode](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript)/[VSCodium](https://open-vsx.org/extension/RokuCommunity/brightscript) BrightScript Language extension. 
3. Hit source control, clone from repository
4. Enter the Git URL of this repository (http clone)
5. Select the folder you want it in
6. Open the folder that you cloned the repository to inside vscodium/vscode
7. Enter `git switch branch device-flow` in the terminal to switch to the `device-flow` branch
8. Create a .vscode folder in the repository's folder.
9. Edit `launch.json` within that folder. Replace IP HERE with your Roku's IP address and ROKU DEV PASSWORD HERE with your Roku's dev password. Make the contents of the file as such:
```
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "brightscript",
            "request": "launch",
            "name": "BrightScript Debug: Launch Remote",
            "stopOnEntry": false,
            "host": "IP HERE",
            "password": "ROKU DEV PASSWORD HERE",
            "rootDir": "${workspaceFolder}/MVP-Roku",
            "enableDebuggerAutoRecovery": false,
            "stopDebuggerOnAppExit": false,
            "enableDebugProtocol": false
        }
    ]
}
```
10. Press F5 to run the app. Press Shift+F5 to stop the app+debugger.

### Settings explained:
* `stopDebuggerOnAppExit` is `false` for testing [Deep Links](https://developer.roku.com/docs/developer-program/discovery/implementing-deep-linking.md).
* `enableDebugProtocol` is `false` because I find the legacy telnet-based connection more reliable with my current setup. If you are on the same network as the Roku, you can try setting this to `true`.
* `rootdir` is `${workspaceFolder}/MVP-Roku` because the app's code exists inside of `./MVP-Roku`
* `enableDebuggerAutoRecovery` is `false` because it happened to cause issues earlier in development. It may interrupt you while writing code if your connection is interrupted to the Roku at any point.

## Developer Instructions                                         
If you want to debug, clone this repository and go to the MVP-Roku folder. You can see the core files such as components, images, etc.

If you want to sideload, just zip the contents of `./MVP-Roku`. If you want to execute it via IDE, check the appropriate plugin/export settings on your IDE.
