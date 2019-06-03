// http://imagej.1557.x6.nabble.com/Randomize-order-of-an-array-td3693530.html

macro "Shuffle Image [F1]"{
setBatchMode(true);
print("\\Clear");

scrambleRound = getNumber("How many rounds?", 1000);

// Original image
var pixelValues = newArray();
origID = getImageID();
getHistogram(values, counts, 256);
for(i=0 ; i<256; i++){
	totalCounts = counts[i];
	for (j=1; j <= totalCounts; j++){
		pixelValues = Array.concat(pixelValues, values[i]);
	}
}

run("Duplicate...", "title=Stack");
stackID = getImageID();

for (r = 1; r < scrambleRound; r++) {
	print("Round = "+ r);
	shuffle(pixelValues);
	//Array.show(pixelValues);
	getDimensions(width, height, channels, slices, frames);
	bits=bitDepth();
	newImage("Untitled", bits+"-bit white", width, height, slices);
	scrambleID = getImageID();
	selectImage(scrambleID);
	scrambleTitle = getTitle();
	var index = 0;
	for (x = 0 ; x<width; x++){
		for (y = 0; y<height; y++){
			setPixel(x, y, pixelValues[index]);
			index++;
		}
	}
	run("Concatenate...", "  title=Stack open image1=Stack image2=scrambleTitle image3=[-- None --]");	
}
setBatchMode(false);
print("DONE");



//---------------------------
function shuffle(array) {
  n = array.length;       // The number of items left to shuffle (loop invariant).
  while (n > 1) {
    k = randomInt(n);     // 0 <= k < n.
    n--;                  // n is now the last pertinent index;
    temp = array[n];      // swap array[n] with array[k] (does nothing if k == n).
    array[n] = array[k];
    array[k] = temp;
  }
}

// returns a random number, 0 <= k < n
function randomInt(n) {
  return n * random();
}

}