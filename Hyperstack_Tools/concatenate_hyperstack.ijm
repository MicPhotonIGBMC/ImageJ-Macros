/* Author : Bertrand Vernay vernayb@igbmc.fr
 * Hyperstack needing to be concatenate must be in a single folder
 * hyperstack should be numbered 01, 02, 03, 05, .... 10, 11, .... , 20
 * 
 * The script: 
 * 		1- analyse the number of slices in all the folder hyperstacks
 * 		2- add balck slices to hyperstack with less slices than the largest hyperstack
 * 		3- create a final hyperstack with all intials hyperstack concatenated together
 */


macro "concatenate hypertack [F1]" {


setBatchMode(true);

dir1 = getDirectory("input");
//dir2 = getDirectory("output");

list = getFileList(dir1);
slicesArray = newArray();

for (i = 0; i<list.length; i++){
	path = dir1 + list[i];
	open(path);
	getDimensions(width, height, channels, slices, frames);
	slicesArray = Array.concat(slicesArray,slices);
	close();
}

//Array.show(slicesArray);
Array.getStatistics(slicesArray, min, max, mean, stdDev);
maxSlices = max;
//print(maxSlices);

for (i = 0; i<list.length; i++){
	path = dir1 + list[i];
	open(path);
	imgName = File.getNameWithoutExtension(path);
	getDimensions(width, height, channels, slices, frames);
	slices = maxSlices - slices;
	if (slices != 0){
		makeNewHyperstack(width, height, channels, slices, frames);
		run("Concatenate...", "  image1="+list[i]+" image2="+imgName+"");
	}
}

run("Concatenate...", "all_open open");
run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices="+maxSlices+" frames="+list.length+" display=Composite");


function makeNewHyperstack(imgWidth, imgHeight, imgChannel, imgSlices, imgFrames) {
	newImage(imgName, "16-bit composite-mode", imgWidth, imgHeight, imgChannel, imgSlices, imgFrames);
}
setBatchMode(false);

}