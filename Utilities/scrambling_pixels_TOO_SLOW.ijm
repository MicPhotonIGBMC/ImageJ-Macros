// TOO SLOW !!!
var pixelValues = newArray();
getDimensions(width, height, channels, slices, frames);
//print(width, height);
for(x=0; x<width; x++){
	print(x);
	for(y=0; y<height; y++){
		value = getPixel(x, y);
		tempArray = newArray(value);
		pixelValues = Array.concat(pixelValues,tempArray);
	}
}
Array.show(pixelValues);
print("DONE");