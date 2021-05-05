/** HyperStackReg_Batch_Align_Channel1_On_Channel2_
 * This ImageJ macro runs HyperStackReg on hyperstacks in input folder and saves
 * registered hyperstacks to output folder.
 * 
 * It assumes the input images have two and only two channels.
 * It registers frames of channel 2 using translations and applies 
 * the same transforms to channel 1.
 * 
 * Copy-Right Marcel Boeglin April 2021
 * e-mail: boeglin@igbmc.fr
 */

var macroname = "HyperStackReg_Batch_Align_Channel1_On_Channel2_";
var version = "05";
var copyright = "Author: Marcel Boeglin - April 2021";
var email = "e-mail: boeglin@igbmc.fr";
var credits = "HyperStackReg: Ved P. Sharma";
var credits2 = "StackReg and TurboReg: P. Thévenaz, U.E. Ruttimann, M. Unser";
var license = "This ImageJ macro is free for mofifcation and redistribution"+
	"\nPlease don't remove initial author.";

var indir, outdir;
var doRegistration = true;
var projTypes = newArray("Average Intensity", "Max Intensity");
var projType = "Max Intensity";
var enhanceInputImages = false;
var enhanceOutputImages = false;
var enhancementOption = "Before Registration";
var enhanceImages = false;
var enhanceChn1 = false;
var enhanceChn2 = false;
var reduceInputToSpotsRegion = false;
var hideImages = false;
var outliersRadius1 = 1;//pixels
var outliersRadius2 = 1;
var subtractBackground1 = true;
var subtractBackground2 = true;
var gaussianSigma1 = 1;//pixels
var gaussianSigma2 = 2;
/*rolling: radius for background subtraction, pixels*/
var rolling1 = 40;//pixels
var rolling2 = 80;
var outliersRadius = 2;//pixels; outliers threshold = 0
var thresholdMethods = newArray("Li", "Moments", "Otsu", "Triangle");
var thresholdMethod = "Li";
var minSpotSize = 1//scaled units (generally micron)


/* Macro Begin */
indir = getDir("Select input folder");
outdir = getDir("Select output folder");
getParams0();
getParams();
print("\\Clear");
printParams();
processFolder(indir, outdir);
/* Macro End */

/*
Further development:

Open TransformationMatrices.txt :
File.openAsString("C:\\Users\\boeglin\\AppData\\Local\\Temp\\TransformationMatrices.txt");
*/

function getParams0() {
	Dialog.create("HyperStackReg_BatchProcessing");
	Dialog.addCheckbox("Do registration (if not, just enhance images)", doRegistration);
	Dialog.show();
	doRegistration = Dialog.getCheckbox();
	if (!doRegistration) {
		enhanceInputImages = true;
		enhanceOutputImages = false;
		enhancementOption = "Before Registration";
		enhanceImages = false;
		enhanceChn1 = true;
		enhanceChn2 = true;
	}
}

function getParams() {
	Dialog.create("HyperStackReg_BatchProcessing");
	Dialog.addCheckbox("Enhance channel 1", enhanceChn1);
	Dialog.addCheckbox("Enhance channel 2", enhanceChn2);
	Dialog.addCheckbox("Crop input to region having spots in channel 1",
		reduceInputToSpotsRegion);
	Dialog.addCheckbox("Hide images during processing (slightly faster)",
		hideImages);
	Dialog.show();
	enhanceChn1 = Dialog.getCheckbox();
	enhanceChn2 = Dialog.getCheckbox();
	enhanceImages = (enhanceChn1 || enhanceChn2);
	reduceInputToSpotsRegion = Dialog.getCheckbox();
	hideImages = Dialog.getCheckbox();
	if (!doRegistration && !enhanceImages) {
		print("\\Clear");
		print("HyperStackReg_BatchProcessing:\nNo Registration, No Enhancement : Aborted");
		showMessage("HyperStackReg_BatchProcessing", "No Registration, No Enhancement : Aborted");
		exit;
	}
	if (enhanceImages) getParams2();
	if (reduceInputToSpotsRegion) getParams3();
}

function getParams2() {
	Dialog.create("HyperstackReg_BatchProcessing");
	items = newArray("Before Registration", "After Registration");
	if (doRegistration) {
		Dialog.addChoice("Enhance Images", items, enhancementOption);
	}
	Dialog.addMessage("Image enhancement parameters channel 1");
	Dialog.addNumber("Outliers radius", outliersRadius1, 0, 4, "pixels");
	Dialog.addCheckbox("Subtract Background", subtractBackground1);
	Dialog.addNumber("Background rolling radius", rolling1, 0, 4, "pixels");
	Dialog.addNumber("Gaussian Blur sigma", gaussianSigma1, 0, 4, "pixels");
	Dialog.addMessage("");
	Dialog.addMessage("Image enhancement parameters channel 2");
	Dialog.addNumber("Outliers radius", outliersRadius2, 0, 4, "pixels");
	Dialog.addCheckbox("Subtract Background", subtractBackground2);
	Dialog.addNumber("Background rolling radius", rolling2, 0, 4, "pixels");
	Dialog.addNumber("Gaussian Blur sigma", gaussianSigma2, 0, 4, "pixels");
	Dialog.show();
	if (doRegistration) {
		enhancementOption = Dialog.getChoice();
	}
	outliersRadius1 = Dialog.getNumber();
	subtractBackground1 = Dialog.getCheckbox();
	rolling1 = Dialog.getNumber();
	gaussianSigma1 = Dialog.getNumber();
	outliersRadius2 = Dialog.getNumber();
	subtractBackground2 = Dialog.getCheckbox();
	rolling2 = Dialog.getNumber();
	gaussianSigma2 = Dialog.getNumber();
	enhanceInputImages = (enhancementOption=="Before Registration");
	enhanceOutputImages = (enhancementOption=="After Registration");
}

function getParams3() {
	Dialog.create("HyperstackReg_BatchProcessing");
	Dialog.addMessage("Spots detection parameters");
	Dialog.addChoice("Projection type", projTypes, projType);
	Dialog.addChoice("Threshold method", thresholdMethods, thresholdMethod);
	Dialog.addNumber("Min spot area", minSpotSize, 1, 4, "scaled units");
	Dialog.show();
	projType = Dialog.getChoice();
	thresholdMethod = Dialog.getChoice();
	minSpotSize = Dialog.getNumber();
}

function printParams() {
	print("\nProcessing parameters:");
	print("Input dir: "+indir);
	print("Output dir: "+outdir);

	print("doRegistration = "+doRegistration);

	print("enhanceImages = "+enhanceImages);
	print("enhanceChn1 = "+enhanceChn1);
	print("enhanceChn2 = "+enhanceChn2);

	print("enhanceInputImages = "+enhanceInputImages);
	print("enhanceOutputImages = "+enhanceOutputImages);
	print("enhancementOption = "+enhancementOption);

	print("outliersRadius1 = "+outliersRadius1);
	print("subtractBackground1 = "+subtractBackground1);
	print("rolling1 = "+rolling1);
	print("gaussianSigma1 = "+gaussianSigma1);

	print("outliersRadius2 = "+outliersRadius2);
	print("subtractBackground2 = "+subtractBackground2);
	print("rolling2 = "+rolling2);
	print("gaussianSigma2 = "+gaussianSigma2);

	print("hideImages = "+hideImages);
	print("reduceInputToSpotsRegion = "+reduceInputToSpotsRegion);
	print("projType = "+projType);
	print("thresholdMethod = "+thresholdMethod);
	print("minSpotSize = "+minSpotSize);
}

function getImageList(dir) {
	list = getFileList(dir);
	list2 = newArray(list.length);
	j=0;
	for (i=0; i<list.length; i++) {
		name = list[i];
		if (endsWith(name, ".tif")) list2[j++] = name;
	}
	return Array.trim(list2, j);
}

function processFolder(dir1, dir2) {
	run("Close All");
	print(macroname+version);
	print(copyright);
	print(email);
	print(license);
	print("Credits:");
	print(credits);
	print(credits2);
	start = getTime();
	if (hideImages) setBatchMode(true);
	imageList = getImageList(dir1);
	nimg = imageList.length;
	for (i=0; i<nimg; i++) {
		imgstart = getTime();
		fname = imageList[i];
		print("\nProcessing "+ (i+1) + " / " + nimg + ":");
		print(fname);
		open(dir1+fname);
		input = getImageID();
		if (enhanceInputImages) {
			input = enhance2channelsImage(input,
				enhanceChn1, outliersRadius1, gaussianSigma1, rolling1,
				enhanceChn2, outliersRadius1, gaussianSigma2, rolling2);
		}
		if (reduceInputToSpotsRegion) cropImageToSpots(input);
		print("HyperstackReg:");
		if (doRegistration)
			run("HyperStackReg ", "transformation=Translation channel2 show");
		output = getImageID();
		if (enhanceOutputImages) {
			//must crop to eliminate bkack border so as Subtract Background...
			//works properly
			run("Z Project...", "projection=[Min Intensity]");
			run("Z Project...", "projection=[Max Intensity]");
			setThreshold(0,1);
			run("Create Selection");
			run("Make Inverse");
			close();
			close();
			selectImage(output);
			run("Restore Selection");
			run("Crop");
			output = enhance2channelsImage(output,
				enhanceChn1, outliersRadius1, gaussianSigma1, rolling1,
				enhanceChn2, outliersRadius1, gaussianSigma2, rolling2);
		}
		outname = substring(fname, 0, lastIndexOf(fname, "."));
		Stack.setChannel(1);
		run("Enhance Contrast", "saturated=0.05");
		Stack.setChannel(2);
		run("Enhance Contrast", "saturated=0.05");
		if (doRegistration)
			saveAs("TIFF", dir2+outname+"_registered.tif");
		else 
			saveAs("TIFF", dir2+outname+"_enhanced.tif");

		run("Close All");
		imageTime = getTime()-imgstart;
		print("Image process time: "+ imageTime/1000 + " s");
		ellapsed = getTime() - start;
		print("Ellapsed time: "+ ellapsed/1000 + " s");
	}
	setBatchMode(false);
	print("\n"+macroname+version+" done");
	processTime = (getTime()- start) / 1000;
	print("Total process time: "+ processTime + " s");
	if (isOpen("Log")) {
		selectWindow("Log");
		saveAs("text", dir2+"Log.txt");
	}
}

function enhance2channelsImage(id, doChn1, outliersR1, sigma1, rolling1,
									doChn2, outliersR2, sigma2, rolling2 ) {
	selectImage(id);
	title = getTitle();
	run("Split Channels");
	list = getList("image.titles");
	chn1 = 0; title1 = "";
	chn2 = 0; title2 = "";
	for (i=0; i<list.length; i++) {
		if (!endsWith(list[i], title)) continue;
		if (startsWith(list[i], "C1-")) {
			selectImage(list[i]);
			chn1 = getImageID();
			title1 = list[i];
		}
		else if (startsWith(list[i], "C2-")) {
			selectImage(list[i]);
			chn2 = getImageID();
			title2 = list[i];
		}
		if (chn1<0 && chn2<0) break;
	}
	if (chn1>=0 || chn2>=0) {
		print("Could not find split channel");
		return id;
	}
	if (doChn1) {
		selectImage(chn1);
		if (outliersR1>=1) {
			run("Remove Outliers...",
				"radius="+outliersR1+" threshold=0 which=Bright stack");
			run("Remove Outliers...",
				"radius="+outliersR1+" threshold=0 which=Dark stack");
		}
		if (subtractBackground1) {
			//print("SUBTRACT BACKGROUND chn1");
			run("Subtract Background...", "rolling="+rolling1+" sliding stack");
		}
		if (sigma1>=0.5)
			run("Gaussian Blur...", "sigma="+sigma1+" stack");
	}
	if (doChn2) {
		selectImage(chn2);
		if (outliersR2>=1) {
			run("Remove Outliers...",
				"radius="+outliersR2+" threshold=0 which=Bright stack");
			run("Remove Outliers...",
				"radius="+outliersR2+" threshold=0 which=Dark stack");
		}
		if (subtractBackground2) {
			//print("SUBTRACT BACKGROUND chn2");
			run("Subtract Background...", "rolling="+rolling2+" sliding stack");
		}
		if (sigma2>=0.5)
			run("Gaussian Blur...", "sigma="+sigma2+" stack");
	}
	run("Merge Channels...", "c1=["+title1+"] c2=["+title2+"] create");
	return getImageID();
}

/**
 * Detects spots according to users parameters and crops input image to
 * smallest rectangle that contains all detected spots */
function cropImageToSpots(id) {
	selectImage(id);
	//wait(4000);
	run("Z Project...", "projection=["+projType+"]");
	//wait(4000);
	Stack.setChannel(2);
	run("Delete Slice", "delete=channel");
	if (!enhanceChn2) {
		run("Remove Outliers...",
			"radius="+outliersRadius2+" threshold=0 which=Bright");
		run("Remove Outliers...",
			"radius="+outliersRadius2+" threshold=0 which=Dark");
		run("Subtract Background...", "rolling="+rolling2);
			run("Gaussian Blur...", "sigma=1");
		run("Gaussian Blur...", "sigma="+sigma2);
	}
	//wait(4000);
	setAutoThreshold("Moments dark");
	run("Analyze Particles...",
		"size="+minSpotSize+"-Infinity exclude clear include add");
	r = computeSpotsRegionBounds();
	print("Crop rectangle:");
	Array.print(r);
	close();
	selectImage(id);
	makeRectangle(r[0], r[1], r[2], r[3]);
	run("Crop");
}

function computeSpotsRegionBounds() {
	width = getWidth(); height = getHeight();
	ndots = roiManager("count");
	if (ndots<2) return newArray(0,0,0,0);
	xmin = getWidth(); xmax = 0;
	ymin = getHeight(); ymax = 0;
	for (i=0; i<ndots; i++) {
		roiManager("select", i);
		Roi.getBounds(x, y, w, h);
		if (x<xmin) xmin = x;
		if (x+w>xmax) xmax = x+w;
		if (y<ymin) ymin = y;
		if (y+h>ymax) ymax = y+h;
	}
	roiManager("deselect");
	roiManager("reset");
	Roi.remove;
	xmin -= 20;
	if (xmin<0) xmin = 0;
	xmax += 20;
	if (xmax>=width) xmax = width-1;
	ymin -= 20;
	if (ymin<0) ymin = 0;
	ymax += 20;
	if (ymax>=height) ymax = height-1;
	//print("xmin="+xmin+"   ymin="+ymin+"   xmax="+xmax+"   ymax="+ymax);
	return newArray(xmin, ymin, xmax-xmin, ymax-ymin);
}

// 80 characters 789 123456789 123456789 123456789 123456789 123456789 123456789