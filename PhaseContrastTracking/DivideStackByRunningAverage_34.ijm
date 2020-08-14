/** ImageJ macro "DivideStackByRunningAverage_33.ijm"

 ¤ If current image is a multi-channel timelapse:
   Extracts the channel corresponding to PH illumination 
   and works with the extracted PH (phase contrast) channel.
   Does nothing if none of its channels has the 'PH' label

 ¤ if current image is a z-stack, does AVG z-projection)

 ¤ Two independent processes to improve images:

   1 - Removal of dirt on camera and optical surfaces with subsidiary
       flat-field correction by ivision of each frame by correction 
       The correction image can be:
       a - a time-average of input frames around frame to be corrected
       b - an empty field image, used for all time points and stage.
           positions.
      Option 1a :
      Correction image is specific of stage position and generally of
      time point. It's obtained as follows:
      - Creation of a sub-stack of constant but adjustable width
        (timeAverageRange) around current frame (the frame to be
        corrected);
        substack first slice: current timepoint - (timeAverageRange-1)/2
        substack last slice: current timepoint + (timeAverageRange-1)/2
      - Average time-projection of substack
      If timeAverageRange is equal to number of frames to be processed,
      the correction image is the same for all time points of current
      stage position.
      Option 1b :
      Correction image is done after removing the sample and is the same for
      all stage positions and time points.
      Such an image can be used only if the sample and its envirnnement do not
      disturb illumination beam. It cannot be used for instance for images
      taken near the border of a well where the surface of the culture medium
      is not horizontal, leading to a displacement of defects in the timelapse
      images.

   2 - Flat-field correction:
       If empty field correction image can be used, division of all frames of
       all positions by this image.
       If not, creation of a pseudo empty field image from each frame of
       each position.
       Creation of correction image of current frame:
       - Frame duplication
       - Removal of dark and bright regions smaller than objects to be detected
       - Gaussian blur
       Current frame is divided by correction image and multiplied by input
       stack's mean value. Subsidiary effect: reduces jumps of frames
       brightness.
 
 * Designed for transmited light timelapse images when illumination
 * is uneven and/or camera's windowis dirty and correction image is
 * not available or can't be used.

 * Author: Marcel Boeglin  -  June-JuLy 2020
 * E-mail: boeglin@igbmc.fr
 */

 /* TODO
 * Proposer de faire spatial defects correction avant constant defects correction
 * (complique mais parfois meilleur resultat)
 */

var input;//input image ID
var transmittedLightSuffix = "PH";
var width, height;
var frames = 1;//of input image
var isCalibrated;//true if input image is calibrated
var xyzUnit, pixelWidth, pixelHeight;
var timeUnit, frameInterval;
var useUserCalibration = false;

var xyzUnits = newArray("micron", "mm", "cm", "m", "pixel");
var timeUnits = newArray("ns", "ms", "s", "min", "hour", "day", "frame");

var startFrame = 1;//1st processes frame
var stopFrame;//lastcorrected frame
var timeAverageRange;
var outputFrames;//number of frames to be processed
var stackMean;//mean pixel value of input image from startFrame to stopFrame

var processed;//ID of processed image
var processedTitle;
var runningSubstack;//ID of substack used to create timeAverageImage
var correctConstantDefects;//defects like dust on camera window
var useTimeAverageImage;
var timeAverageCorrectionPercentage;//output = mix of input and corrected images
var useBlankFieldImage;
var blankFieldImage;//ID of blank field image

/* Correct defects due for instance to imaging near border of a well.
 * Correction is calculated and done for each frame independently. */
var doSpatialCorrection;

var objectsSize = 40;/* physical units (micron, mm, cm, ...) */
var objectsSizePixels;
var timeAverageRange;

var minmaxRadius = 0;
var gaussianSigma = 0;

var batchProcessing;
var dir1, dir2;
var include;
var exclude;
var swapZandT;
var count;

print("\\Clear");

if (nImages>0) {
	input = getImageID();
	Stack.getDimensions(width, height, channels, slices, frames);
	if (channels>1) getTransmittedLightSuffix();
/*
	swapSlicesAndFrames(); input = getImageID();
	//PROBLEM: input can no longer be thresholded,
	//changes pixelWidth & pixelHeigh
*/
	checkAndFormat(input);
	if (!isCalibrated) {
		calibrationDialog();
		setCalibrationFromUser();
	}

	//print("isCalibrated = "+isCalibrated);
	timeRangeDialog();
}
else {
	batchProcessing = true;
}

outputFrames = stopFrame - startFrame + 1;
//timeAverageRange = Math.floor(outputFrames/8);
timeAverageRange = Math.floor(outputFrames);
makeTimeAverageRangeUneven();

if (batchProcessing) {
	print("\nBatch Processing:\n ");
	dir1 = getDir("Input folder");
	dir2 = getDir("Output folder");
	batchProcessingDialog();
	files = getFileList(dir1);
	//count = 0;
	for (i=0; i<files.length; i++) {
		fname = files[i];
		print("fname = "+fname);
		regex = ".*\\.tif|TIF|zip";
		if (!matches(fname, regex)) continue;
		if (include!="" && indexOf(fname, include)<0) continue;
		if (exclude!="" && indexOf(fname, exclude)>=0) continue;
		run("Close All");
		open(dir1+fname);
		if (nImages==0) continue;
		input = getImageID;
/*
		if (swapZandT) {
			swapSlicesAndFrames();doesn't work properly
		}
*/
		if (!checkAndFormat(input)) {
			run("Close All");
			continue;
		}
		print("count = "+count);
		if (count++ == 0) {
			if (useUserCalibration) {
				calibrationDialog();
			}
			//calibrationDialog();
			//checkAndFormat(input);
			//getProperties(input);
			//print("count = "+count);
			timeRangeDialog();
			outputFrames = stopFrame - startFrame + 1;
			//timeAverageRange = Math.floor(outputFrames/8);
			timeAverageRange = Math.floor(outputFrames);
			makeTimeAverageRangeUneven();
			processingParamsDialog();
		}

		if (!isCalibrated && useUserCalibration) {
			setCalibrationFromUser();
		}
		processImage();
		selectImage(processed);
		outname = substring(fname, 0, lastIndexOf(fname, "."));
		outname += "_illumCorrected.zip";
		print("outname = "+outname);
		path = dir2+outname;
		if (File.exists(path)) File.delete(path);
		//overwrite zip forbiden by Windows !
		saveAs("zip", path);
		run("Close All");
	}
}
else {
	processingParamsDialog();
	processImage();
}

//End macro

function setCalibrationFromUser() {
	//if (isCalibrated) return;
	Stack.setUnits(xyzUnit, xyzUnit, xyzUnit, timeUnit, Value);
	setVoxelSize(pixelWidth, pixelWidth, pixelWidth, xyzUnit);
	Stack.setFrameInterval(frameInterval);
}

function makeTimeAverageRangeUneven() {
	//problems if timeAverageRange small
	if (timeAverageRange<3) timeAverageRange = 3;
	if (timeAverageRange%2==0) timeAverageRange += 1;
	if (timeAverageRange>outputFrames) {
		timeAverageRange = outputFrames;
		if (timeAverageRange%2==0) timeAverageRange -= 1;
	}
}

function processingParamsDialog() {
	Dialog.create("Transmitted-Light Timelapse Illumination Correction");
	Dialog.addCheckbox("Correct roughly time-independent illumination defects", true);
	label = "by";
	choices = newArray(2);
	choices[0] = "time average projection";
	choices[1] = "empty field image";
	Dialog.addChoice(label, choices, choices[0]);
	Dialog.addNumber("Time Average Range",
			timeAverageRange, 0, 4, "frames (odd)");
	Dialog.addNumber("Correct time-independent defects at", 100, 0, 4, "%");
	Dialog.addMessage("If time-independent defects correction << 100%"+"\nor"+
			"\ntime average range larger than defects variation time-scale,"+
			"\nvariable illumination defects correction may be necessary.");
	Dialog.addCheckbox("Correct variable illumination defects ", true);
	Dialog.addNumber("Size of objects to be preserved",
			objectsSize, 2, 7, xyzUnit);
	Dialog.addCheckbox("Batch processing with these parameters", batchProcessing);
	Dialog.show();
	correctConstantDefects = Dialog.getCheckbox();
	choice = Dialog.getChoice();
	useTimeAverageImage = (choice == choices[0]);
	useBlankFieldImage = (choice == choices[1]);
	timeAverageRange = Dialog.getNumber();
	timeAverageCorrectionPercentage = Dialog.getNumber();
	doSpatialCorrection = Dialog.getCheckbox();
	objectsSize = Dialog.getNumber();
	batchProcessing = Dialog.getCheckbox();
	makeTimeAverageRangeUneven();
	if (!doSpatialCorrection) {
		timeAverageCorrectionPercentage = 100;
		//then TimeAverageCorrection provides also spatial correction
	}
	printParams();
	if (useBlankFieldImage) {
		id = 0;
		if (nImages>0) id = getImageID();
		waitForUser("Select or open Blank Field Image");
		blankFieldImage = getImageID();
		if (isOpen(id)) selectImage(id);
	}
}

function printParams() {
	print("");
	print("correctConstantDefects = "+correctConstantDefects);
	print("useBlankFieldImage = "+useBlankFieldImage);
	print("useTimeAverageImage = "+useTimeAverageImage);
	print("timeAverageRange = "+timeAverageRange);
	print("timeAverageCorrectionPercentage = "+timeAverageCorrectionPercentage);
	print("doSpatialCorrection = "+doSpatialCorrection);
	print("objectsSize = "+objectsSize+" "+xyzUnit);
	print("batchProcessing = "+batchProcessing);
	if (batchProcessing) {
		print("");
		print("dir1: "+dir1);
		print("dir2: "+dir2);
		print("include = "+include);
		print("exclude = "+exclude);
		print("swapZandT = "+swapZandT);
		print("");
		print("useUserCalibration = "+useUserCalibration);
		print("Calibration from user:");
		print("xyzUnit = "+xyzUnit);
		print("pixelWidth = "+pixelWidth);
		print("pixelHeight = "+pixelHeight);
		print("timeUnit = "+timeUnit);
		print("frameInterval = "+frameInterval);
	}
	print("");
}

function getTransmittedLightSuffix() {
	Dialog.create("Transmitted-Light Timelapse Illumination Correction");
	Dialog.addString("Transmitted light suffix", transmittedLightSuffix);
	Dialog.show();
	transmittedLightSuffix = Dialog.getString();
}

function timeRangeDialog() {
	startFrame = 1;
	stopFrame = frames;
	//User interface 1 : limit output time range
	Dialog.create("Transmitted-Light Timelapse Illumination Correction");
	Dialog.addNumber("First frame ", startFrame);
	Dialog.addNumber("Lastt frame ", stopFrame);
	Dialog.show();
	startFrame = Dialog.getNumber();
	stopFrame = Dialog.getNumber();
}

function batchProcessingDialog() {
	Dialog.create("Timelapse batch correction");
	Dialog.addString("Process filenames containing", "", 30);
	Dialog.addString("Exclude filenames containing", "", 30);
	//Dialog.addCheckbox("Swap Z and T in all images", false);
	Dialog.addCheckbox("If images are uncalibrated,"+
			" use calibration from next dialog", false);
	Dialog.show();
	include = Dialog.getString();
	exclude = Dialog.getString();
	//swapZandT = Dialog.getCheckbox();
	useUserCalibration = Dialog.getCheckbox();
}

function calibrationDialog() {
	Dialog.create("Calibration");
	Dialog.addMessage("Uncalibrated images calibration:", false);
	Dialog.addChoice("Spatial unit", xyzUnits, "micron");
	Dialog.addNumber("Pixel size", pixelWidth, 4, 10, "");
	Dialog.addChoice("Time unit", timeUnits, "s");
	Dialog.addNumber("time interval", frameInterval, 4, 10, "");
	Dialog.show();
	xyzUnit = Dialog.getChoice();
	pixelWidth = Dialog.getNumber();
	pixelHeight = pixelWidth;
	timeUnit = Dialog.getChoice();
	frameInterval = Dialog.getNumber();
}

/* doesn't work properly */
function swapSlicesAndFrames() {//DON'T USE
	run("Re-order Hyperstack ...",
		"channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	//should be followed by setProperties()
}

/* gets properties of 'image'
 * if multi-channel: reduces to phase contrast channel
 * if z-stack: does AVG z-projection
 * returns false if not a timelapse or nFrames<4 */
function checkAndFormat(image) {//REVOIR les differents cas possibles
//	id = 0;
//	if (nImages>0) id = getImageID();
	selectImage(image);
	title = getTitle();
	Stack.getDimensions(width, height, channels, slices, frames);
	if (frames<4) return false;
	if (slices>1) {
		print("Input image is a z-stack. Doing Average z-projection");
		run("Z Project...", "projection=[Average Intensity] all");//all frames
		projID = getImageID();
		selectImage(image);
		close("");
		selectImage(projID);
		rename(title);
	}
	if (slices>1 && frames==1) {
		//Other possibiliy: do Average projection
		showMessageWithCancel("Image seems not to be a timelapse image\n"+
				"Change slices to frames ?");
		Stack.setDimensions(channels, frames, slices);
	}
	if (channels>1) {
		for (c=1; c<=channels; c++) {
			Stack.setChannel(c);
			label = getInfo("slice.label");
			if (indexOf(label, transmittedLightSuffix)>0) break;
		}
		run("Reduce Dimensionality...", "frames");
		input = getImageID();
	}
	width = getWidth();
	height = getHeight();
	print("width = "+width+"    height = "+height);
	Stack.getDimensions(width, height, channels, slices, frames);
	print("channels = "+channels);
	print("slices = "+slices);
	print("frames = "+frames);
	frameInterval = Stack.getFrameInterval();
	print("frameInterval = "+frameInterval);
	Stack.getUnits(X, Y, Z, timeUnit, Value);
	print("Time unit : "+timeUnit);
	getPixelSize(xyzUnit, pixelWidth, pixelHeight);
	print("xyz unit : "+xyzUnit);
	//User Interface : physical units
	//conversion in pixels if process in pixels
//	if (id<0) selectImage(id);
	hasSpatialCalibration = (xyzUnit!="" && xyzUnit!="pixel");
	hasTimeCalibration = (frameInterval!=0);
	isCalibrated = (hasSpatialCalibration && hasTimeCalibration);
	print("hasSpatialCalibration = "+hasSpatialCalibration);
	print("hasTimeCalibration = "+hasTimeCalibration);
	print("isCalibrated = "+isCalibrated);
	return true;
}

function getProperties(image) {
	id = 0;
	if (nImages>0) id = getImageID();
	selectImage(image);
	width = getWidth();
	print("width = "+width);
	height = getHeight();
	Stack.getFrameInterval();
	Stack.getDimensions(width, height, channels, slices, frames);
	Stack.getUnits(X, Y, Z, timeUnit, Value);
	getPixelSize(xyzUnit, pixelWidth, pixelHeight);
	//User Interface : physical units
	//conversion in pixels if process in pixels
	if (id<0) selectImage(id);
}

function processImage() {
	objectsSizePixels = Math.floor(objectsSize/pixelWidth);
	run("Select None");
	stackMean = getStackMean(input, startFrame, stopFrame);
	title = getTitle();
	if (indexOf(title, ".")>=0)
		title = substring(title, 0, lastIndexOf(title, "."));
//	print("correctConstantDefects = "+correctConstantDefects);
//	print("useTimeAverageImage = "+useTimeAverageImage);
//	print("useBlankFieldImage = "+useBlankFieldImage);
	if (correctConstantDefects && useTimeAverageImage) {
		//do no spatial averaging, only time averaging
		//keep original
		run("Select None");
		run("Duplicate...", "title="+title+"_DividedBy"+timeAverageRange+
			"AveragedSlices duplicate range="+startFrame+"-"+stopFrame);
		processed = getImageID();
		processedTitle = getTitle();
//		print("timeAverageRange = "+timeAverageRange);
//		print("minmaxRadius = "+minmaxRadius);
//		print("gaussianSigma = "+gaussianSigma);
		radius = 0; sigma = 0;
		divideByRunningStackAverage(processed, timeAverageRange, radius, sigma);
	}
	if (correctConstantDefects && useBlankFieldImage) {
		//divide each frame by blankFieldImage:
		//Can work ONLY if dirt image is independent of stage position.
		//
		//CAN'T WORK for positions near the edge of a well because the non
		//horizontal surface of culture medium deviates the iillumination beam,
		//leading to a displacement of the dirts in blank field image
		//
		//do optional Spatial Average Correction of blankFieldImage
		//(not a good idea)
		selectImage(blankFieldImage);
		run("Select None");
		run("Duplicate...", "title=divisor");
		if (getWidth()!=width || getHeight()!=height) {
			run("Size...", "width="+width+" height="+height+
					" depth=1 constrain average interpolation=Bilinear");
		}
		divisor = getImageID();
		divisorTitle = getTitle();//CalculatorPlus uses title

		if (false) {//do following perhaps not a good idea
			run("Duplicate...", "title=divider");
			divider = getImageID();
			dividerTitle = getTitle();
			print("minmaxRadius = "+minmaxRadius);
			print("gaussianSigma = "+gaussianSigma);
			removeDarkAndBrightZones(divider, 1, 1, minmaxRadius);
			run("Gaussian Blur...", "sigma="+gaussianSigma);
			divider = getImageID();
			dividerTitle = getTitle();
			getStatistics(area, mean, min, max, std, histogram);
			run("Calculator Plus", "i1="+divisorTitle+" i2="+dividerTitle+
					" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+
					mean+" k2=0 create");
			selectImage(divider);
			close();
		}

		getStatistics(area, mean, min, max, std, histogram);
		print("mean = "+mean);
		print("divisorTitle = "+divisorTitle);
		//keep original
		selectImage(input);
		inputTitle = getTitle();
		run("Select None");
		run("Duplicate...",
				"title=TEMP duplicate range="+startFrame+"-"+stopFrame);
		run("Calculator Plus", "i1="+"TEMP"+" i2="+divisorTitle+
				" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+mean+
						" k2=0 create");
		if (isOpen("TEMP")) {
			selectWindow("TEMP");
			close();
		}
		if (isOpen("divisor")) {
			selectWindow("divisor");
			close();
		}
		selectWindow("Result");
		rename(title+"_DividedByBlankFieldImage");
		processed = getImageID();
		processedTitle = getTitle();
	}
	if (doSpatialCorrection) {
		print("");
		// si on ne duplique pas, travaille sur l'original et non sur le
		// resultat de l'operation precedente
		run("Select None");
		if (correctConstantDefects)
			run("Duplicate...", "duplicate");
		else
			run("Duplicate...", "duplicate range="+startFrame+"-"+stopFrame);
		processed = getImageID();
		processedTitle = getTitle();
		minmaxRadius = Math.floor(objectsSizePixels/4);
		gaussianSigma = Math.floor(objectsSizePixels/4);
		tAvgRange = 1;
		selectImage(processed);
		print("tAvgRange = "+tAvgRange);
		print("minmaxRadius = "+minmaxRadius);
		print("gaussianSigma = "+gaussianSigma);
		divideByRunningStackAverage(processed,
		tAvgRange, minmaxRadius, gaussianSigma);
	}
}//function processImage()

/* Modifie 'outputImage' sans creer de copie
 cree runningSubStack et le detruit a la fin du processus
 minmaxRadius: si > 0, reduit les zones claires et les zones sombres
 gaussianSigma si > 0, fait gaussian-blur des projections AVG du runningSubstack
*/
function divideByRunningStackAverage(outputImage,
		runningStackSize, minmaxRadius, gaussianSigma) {
	print("divideByRunningStackAverage()");
	print("runningStackSize = timeAverageRange = "+runningStackSize);
	id = 0;
	if (nImages>0) id = getImageID();
	selectImage(outputImage);
	print("Processing "+getTitle());
	outputFrames = nSlices;
	runningSubstack = 0;
	if (runningStackSize>1) {
		run("Duplicate...",
				"title=Running_Substack duplicate range=1-"+runningStackSize);
		if (minmaxRadius>0)
			removeDarkAndBrightZones(runningSubstack,
					1, runningStackSize, minmaxRadius);
		runningSubstack = getImageID();
	}
	setBatchMode(true);
	if (runningStackSize==1) {
		//create a copy of current slice, remove dark and bright, geussian blur
		//divide current slice by processed copy and multiply by average pixels
		//value
		for (i=1; i<=outputFrames; i++) {
			setSlice(i);
			run("Duplicate...", "title=divisor");
			divisor = getImageID();
			divisorTitle = getTitle();//CalculatorPlus utilise title
			removeDarkAndBrightZones(divisor, 1, 1, minmaxRadius);
			run("Gaussian Blur...", "sigma="+gaussianSigma);
			//print("runningStackSize = 1 : divisorTitle = "+divisorTitle);
			selectImage(outputImage);
			setSlice(i);
			run("Duplicate...", "title=originalSlice_"+i);
			inputSliceDUP = getImageID();
			inputSliceDUPname = getTitle();
			run("Calculator Plus", "i1="+inputSliceDUPname+" i2="+divisorTitle+
					" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+
					stackMean+" k2=0 create");
			resultTitle = getTitle();
			result = getImageID();
			//print("resultTitle = "+resultTitle);
			run("Select All");
			run("Copy");
			close();
			selectImage(outputImage);
			setSlice(i);
			run("Select All");
			run("Paste");
			run("Select None");
			selectImage(divisor);
			close();
		}
	}
	else {//runningStackSize > 1
		//print("runningStackSize/2 = "+runningStackSize/2);
		selectImage(runningSubstack);
		run("Z Project...", "projection=[Average Intensity]");
		divisor = getImageID();
		divisorTitle = getTitle();//CalculatorPlus utilise title
		print("divisorTitle = "+divisorTitle);
		for (i=1; i<=outputFrames; i++) {
			//print("runningSubstack title = "+getTitle());
		//	setBatchMode("hide");
			//getStatistics(area, mean, min, max, std, histogram);
			selectImage(outputImage);
			setSlice(i);
			run("Duplicate...", "title=inputSliceDUP_"+i);
			inputSliceDUP = getImageID();
			inputSliceDUPname = getTitle();
			run("Calculator Plus", "i1="+inputSliceDUPname+" i2="+divisorTitle+
					" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+
					stackMean+" k2=0 create");
			resultTitle = getTitle();
			result = getImageID();
			//print("resultTitle = "+resultTitle);
			mix(inputSliceDUP, result, timeAverageCorrectionPercentage);
			inputSliceDUP = getImageID();

			run("Select All");
			run("Copy");
			close();
			selectImage(outputImage);
			setSlice(i);
			run("Select All");
			run("Paste");
			run("Select None");
//			wait(1000);
			if (i>=runningStackSize/2 && i<=outputFrames-runningStackSize/2) {
				selectImage(input);
				currentFrame = startFrame + i;//seems ok
				if (currentFrame>outputFrames) break;
				//print("Moving runningSubstack 1 frame towards stop frame");
				//print("currentFrame = "+currentFrame);
				setSlice(currentFrame);
				run("Select All");
				run("Copy");
				run("Select None");
				if (runningSubstack<0) {//image exists
					selectImage(runningSubstack);
					//supprimer 1er slice, ajouter slice a la fin, 
					//y copier slice (startFrame + i) de l'original
					setSlice(1);
					run("Delete Slice");
					setSlice(runningStackSize-1);
					run("Add Slice");
					run("Select All");
					run("Paste");
					run("Select None");
				}
			}
			if (isOpen(inputSliceDUPname)) {
				selectWindow(inputSliceDUPname);
				close();
			}
			if (isOpen(divisor)) {
				selectImage(divisor);
				close();
			}
			selectImage(runningSubstack);
			run("Z Project...", "projection=[Average Intensity]");
			//print("Object size = "+objectSize);
			divisor = getImageID();
			divisorTitle = getTitle();//CalculatorPlus utilise title
			//print("divisorTitle = "+divisorTitle);		
		}
		if (isOpen(runningSubstack)) {
			selectImage(runningSubstack);
			close();
		}
		if (isOpen(divisor)) {
			selectImage(divisor);
			close();
		}
	}//runningStackSize > 1
	setBatchMode(false);
	selectImage(outputImage);
	processed = getImageID();
	setOption("Changes", false);
	run("Select None");
}// function divideByRunningStackAverage()


/* Adds image2Percent image2 to image and closes image2 */
function mix(image, image2, image2Percent) {
	//utiliser ImageCalculator car CalculatorPlus cree une nouvelle image
	//multiplier image par (100 - image2Percent) / 100
	//multiplier image2 par image2Percent / 100
	//ajouter image2 a image sans creer une nouvelle image
	selectImage(image);
	title = getTitle();
	run("Multiply...", "value="+((100-image2Percent)/100));
	selectImage(image2);
	title2 = getTitle();
	run("Multiply...", "value="+(image2Percent/100));
	imageCalculator("Add", title, title2);//modifie 1ere image
	selectWindow(title2);//2eme image
	close();
}

/* Removes dark and bright zones within radius
 * from first slice to lastSlice of 'image'
 * image : the ID of stack to be processed */
function removeDarkAndBrightZones(image, firstSlice, lastSlice, radius) {
	//essayer remove outliers
	id = 0;
	if (nImages>0) id = getImageID();
	selectImage(image);
	for (i=firstSlice; i<=lastSlice; i++) {
		setSlice(i);
		run("Minimum...", "radius="+radius);
		run("Maximum...", "radius="+radius);
		run("Maximum...", "radius="+radius);
		run("Minimum...", "radius="+radius);
	}
	if (id<0) selectImage(id);
}

/* Returns mean pixel value of 'image' from 'firstSlice' to 'lastSlice'
 * Returns 0 if 'image' not found or is a Hyperstack */
function getStackMean(image, firstSlice, lastSlice) {
	//print("getStackMean: firstSlice = "+firstSlice+"   lastSlice = "+lastSlice);
	if (image>=0) return 0;
	id = 0;
	if (nImages>0) id = getImageID();
	if (lastSlice < firstSlice) return 0;//a revoir
	Mean = 0;
	selectImage(image);
	if (Stack.isHyperstack) return 0;
	for (i=firstSlice; i<=lastSlice; i++) {
		getStatistics(area, mean, min, max, std, histogram);
		Mean += mean;
	}
	if (id<0) selectImage(id);
	return Mean/(lastSlice-firstSlice+1);
}


/*
 * Essais de traitements ulterieurs (parametres pour images Sarah Djerroud
 * downSample4x): 
 */

/*
Max 0.5 pix // elimine les projections
Min 0.5 pix
Gauss 1 pix
*/

/*
run("Invert", "stack");
soustraire valeur moyenne du fond
eventuellement gaussian blur ~ 1 pix
run("FeatureJ Hessian", "largest smoothing=6");//pas trop mal essayer 5
run("FeatureJ Hessian", "largest smoothing=4");//pas mal (mieux que 6)
*/

/*
NTA/NanoTrackJ ok
MTrackJ : inutilisable
message d'erreur pour chaque frame si image ou parametre incorrect !
*/
