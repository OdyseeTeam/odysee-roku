rm ../png/*.png #clean output
for file in $(ls | grep svg); do curfile=$(echo $file | cut -d "." -f1); inkscape --export-filename=$curfile.png -z -w 64 -h 64 $curfile.svg; done #convert
mv *.png ../png/