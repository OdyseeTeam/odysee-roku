# This is the svg images folder. These images are converted to png and then used in the Roku app.
## WORKFLOW
1. Go to Odysee.com, open chrome dev console
2. Use "select an element from the page to inspect it/ctrl+shift+c"
3. Hover over an Icon on the sidebar
4. Go into the tab, find <svg
5. Copy element
6. Paste into a text editor and save as .svg named as that icon
7. Manually go into Inkscape for each individual icon. Ctrl+A, Stroke paint to white flat color, and save the icon.
8. Run convert.sh