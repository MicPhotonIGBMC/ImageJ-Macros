/** 
 *  AdjustRoiGridToImage_And_MeasureDots_.ijm
 *  
 *  This ImageJ macro measures the fluorescence in a folder of .czi images
 *  where the samples are localized in a rectangular array of approximatively
 *  circular wells.
 *  The array is assumed to have same dimensions and numbers of rows and
 *  columns in all images of the folder (for instance 5 x 5 wells).
 * 
 *  Being obtained by stiching of a mosaic, the images have variable sizes.
 *  The samples may be tilted, resulting in oblique arrays of wells.
 *  The well shapes may differ significantly from circles.
 *  
 *  Each image has several fluorescence channels and a brightfield channel
 *  which is assumed to be the last one and is used for the detection of the 
 *  well outlines (some of them may have no fluorescence).
 *  The fluorescence channels are obtained from a unique staining with
 *  increasing exposure times from channel 1 to nChannels-1.
 *  
 *  Two protocols for the measurement of the fluorescence are planned:
 *  1. Measure the signal in circular Rois. Their radius is chosen small enough
 *     to ensure the circle can be contained in each well of each image in the
 *     folder. Circle positions can be centered individually in each well.
 *     The Rois grid is either loaded from an Roi-set on the disk or computed
 *     from its width, height, numbers of rows and columns and the radius of
 *     the measurement circles. From version 25, the Roi-grid from the disk
 *     must be based on an image of pyramidal resolution #3.
 *  2. Measure the signal in whole wells by automatic outlines detection.
 *
 *  For each multi-channel image in the input folder, the macro: 
 *  - Fits the predefined or computed Roi-grid to the array of wells detected
 *    in the brightfield channel by a rotation and a translation;
 *  - Measures the signal in each fluorescence channel inside each Roi which
 *    may be either the well outline or a circle;
 *  - Saves a view of each channel with a drawing of the measurements Rois
 *    and corresponding results table to output folder.
 *  - Optionally detects the fluorescence map in each well of each channel
 *    using well dependent auto-threshold or well independent custom
 *    threshold, meassures the signal and saves the channel with well-outline
 *    and fluorescence outline in the overlay to output folder.
 * 
 *  The macro saves also to the output folder measurement results as csv files
 *  and a Log file containing the macro parameters and the processed file-list.
 * 
 * 
 *  Author: Marcel Boeglin - February - April 2021
 *  boeglin@igbmc.fr
 *  
 *  This macro can be modified and redistributed.
 *  Please do not remove the initial author.
 *  
 */

/* 
 * To simplify the code, accelerate execution and avoid malfunction due to bugs
 * of ImageJ occuring with large images, all segmentation and Roi operations
 * are performed at lowest resolution (#3). For the same reasons, rotation and
 * translation of the Roi-grid are computed on the copy of the BF channel
 * reduced to the size of resolution #3 whatever the resolution (#1, #2 or #3)
 * chosen for the signal measurement. The counterpart is less precision in
 * well outlines for images at resolution #2 and #3.
 */

var version = 46;
var macroname = "AdjustRoiGridToImage_And_MeasureDots_"+version;
var copyRight = "Author: Marcel Boeglin February - April 2021";
var email = "boeglin@igbmc.fr";

var bugedBioFormat = true;

/* AutoThreshold methods for Well detection from BF inside an Roi
 somewhat larger than well-size given by user */
var wellThrMethodsBF = newArray("Default", "Huang", "IsoData", "Li",
								"MaxEntropy", "Mean", "Moments", "Otsu",
								"RenyEntropy", "Triangle", "Yen");
var wellsThrMethodBF = "Default";

//NOT USED
/* AutoThreshold methods for Well detection from Fluo inside an Roi 
 somewhat larger than well-size given by user; 
 uses autofluorescence in empty wells
 Needs preliminary wells detection in brightfield */
var wellThrMethodsFluo = newArray("Huang", "Mean", "Otsu");
var wellThrMethodFluo = "Huang";
var refineWellShapesFromFluo = false;
//NOT USED

/* Fluo autoThresholds inside Rois somewhat larger than wells
 for DotShape analyzis */
//Li ? MinError ? Triangle ?
var dotShapeThrMethods = newArray("Default", "IsoData", "Moments");
var dotShapeThrMethod = "IsoData";
var dotsDrawingColor = "green";

var roiShapes = newArray("Circles", "Well_Outlines");
var roiShape = "Circles";
var roiShape = "Well_Outlines";
var interpolateWellOutlines = true;
var interval = 2;//pixels in image #3


/* 'doAnalyzeDotShapes' if true, analyze dot patterns
needs roiShape = "Well_Outlines" */
var doAnalyzeDotShapes = true;
var dotShapesAnalyzisThresholdOptions = newArray("Fixed_Threshold",
	"AutoThreshold");
var dotShapesAnalyzisThresholdOption = "Fixed_Threshold";
/** Let maxWellMean be the maximum mean signal of all wells in current image:
 * if mean signal in a given well is larger than 
 * maxWellMean / positiveWellSignalRatio then the well is considered as
 * positive and dot shapes will be analyzed */
var positiveWellSignalRatio;
/** Fluorescent dots smaller than average well area divided by this number
 * are ignored */
var minDotAreaRatio = 100;

var drawingColors = newArray("red","green","blue","cyan","magenta","yellow",
		"white","black","gray","darkgray","orange","pink");
var wellsDrawingColor = "black";
var dbug = false;
var hideImages = true;
var dir1, dir2;
var images;//list of .czi files in dir1

var gridSources = newArray("Disk (grid for #3)","Computation");
var gridSource = "Computation";

/* Predefined Roi-grid loaded from disk */
var roisScalingFactor = 0.75;
var RoiGridPath;
var RoiGridDir;
var RoiGridName;
var flipRoiGridHorizontally = false;
//Wells detection in brightfield image
var expectedWellDiameter=530;//physical units
var tolerance=25;//%

/* Automatic Roi-grid creation
	It's assumed the grid is scanned row by row from top to bottom
	and that rows are all scanned in same direction */
var gridCenterX, gridCenterY;//physical units
var xStep, yStep;//physical units
var gridCols=5, gridRows=5;
var roisRadius=expectedWellDiameter/2;//physical units, for grid computation
var minWellDiameter, maxWellDiameter;
var scanDirections = newArray("LeftToRight", "RightToLeft");
var scanDirection="RightToLeft";
var fitSquare = true;
var gridWidth=4824, gridHeight=4824;//physical units
var calculateGridDimensions = false;

var centerRoisIndividually = true;

/*
 * Bug in Bioformat: The Zeiss image dimensions are divided by 3 at each
 * resolution step: 900 pix in image #1 -> 300 pix in #2, 100 pix in #3
 * but images #2 and #3 have the same pixelSize image #1.
 * To workaround the bug, we multiply pixelWidth & pixelHeight by 
 * 3 power (pyramidalResolution - 1) */
var pyramidalResolution = "2";
var width, height, channels, slices, frames, npixels;//of image
var pixelWidth, pixelHeight, unit;

var nDots;
var wellsDetectionFailed;

/* 4 Corners of dots array in images as arrays (x,y)
	Coordinates in physical units */
var TopLeft=newArray(2), BottomRight=newArray(2);
var TopRight=newArray(2), BottomLeft=newArray(2);

var inputImg;

/* Radius of rolling ball for subtract background of BF before segmentation */
var rollingRadius = 900;//in scaled units (micron)
/* Apply gaussian blur to brightfield channel for better segmentation */
var gaussianBlurSigma = 2;//in scaled units (micron)
/*multiply brightfield by this after convert to 8-bit to reduce well intensity
 *  differences. Best value depends on wellsThrMethodBF */
var intensityFactor = 1.8;
/* 'segmentationGamma' reduces well intensity differences in BF */
var segmentationGamma = 0.80;
var processedBrightfield;//ID of processed BF for segmentation
//var resizeFactor;
var wellSizeCorrectionFactor = 0.99;

var sampleTilt;

var outputname;
var outputBitDepth = "8-bit";
var outputGamma = 0.67;
var strokeWidth = 0;


/*----------- Macro begin -----------*/

print("\\Clear");
getParams();
getParams2();
getParams3();
if (doAnalyzeDotShapes) getParams4();

if (gridSource=="Disk (grid for #3)") {
	RoiGridPath = File.openDialog("Select RoiGrid");
	RoiGridDir = File.getDirectory(RoiGridPath);
	RoiGridName = File.getName(RoiGridPath);
}
dir1 = getDirectory("Select input folder with .czi files"); 
dir2 = getDirectory("Select output folder");

images = getFileList(dir1);
images = filterList(images, ".czi");
nimages = images.length;

print(macroname);
print(copyRight);
print(email);
print("");
if (wellsThrMethodBF=="Triangle" || wellsThrMethodBF=="Yen") {
	print("BrightField segmentation method = "+wellsThrMethodBF+":"+
		"intensityFactor and segmentationGamma set to 1");
	intensityFactor = 1;
	segmentationGamma = 1;
}
printParams();
print("RoiGridDir: "+RoiGridDir);
print("RoiGridName: "+RoiGridName);
IJ.redirectErrorMessages();

//print("\n \nProcessing folder\n ");
start = getTime();
processFolder();
print("\n"+macroname+" done");
print("Process time: "+(getTime()-start)/1000+" s");
print("");
selectWindow("Log");
saveAs("Text", dir2+"Log_#"+pyramidalResolution+".txt");
if (isOpen("ROI Manager")) {
	selectWindow("ROI Manager");
	run("Close");
}

/*----------- Macro end -----------*/


function getParams() {
	Dialog.create("AdjustRoiGridToImage_And_Measure_"+version);
	Dialog.addCheckbox("Workaround Zeiss multi-scale calibration bug in"+
		" Bioformat", bugedBioFormat);
	Dialog.addChoice("Image resolution: #",
		newArray("1","2","3"), pyramidalResolution);

	Dialog.addMessage("");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Wells detection:");
	Dialog.addNumber("Expected well diameter",
		expectedWellDiameter, 2, 7, "(physical units)");
	Dialog.addNumber("Tolerance for well diameter: +/-", tolerance, 0, 5, "%");
	Dialog.addNumber("Background subtraction radius",
		rollingRadius, 2, 6, "(physical units)");
	Dialog.addNumber("Gaussian blur sigma",
		gaussianBlurSigma, 2, 5, "(physical units)");
	Dialog.addNumber("Gamma",
		segmentationGamma, 1, 4, "");
	Dialog.addNumber("Multiply intensity by",
		intensityFactor, 1, 4, "");
	Dialog.addChoice("Autothreshold method",
		wellThrMethodsBF, wellsThrMethodBF);
	Dialog.addNumber("Scale detected wells by",
		wellSizeCorrectionFactor);

	Dialog.addMessage("");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("\nRoi-grid adjustment to detected vells:");
	Dialog.addChoice("Roi-grid source", gridSources, gridSource);
	Dialog.addChoice("Measurement-rois shapes", roiShapes, roiShape);
	Dialog.addCheckbox("Center measurement-rois individually on detected wells",
		centerRoisIndividually);

	Dialog.addMessage("");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("\nOutput Images:");
	Dialog.addChoice("Bit-Depth", newArray("8-bit","16-bit"), "8-bit");
	Dialog.addNumber("Gamma", 0.6);
	Dialog.addNumber("Wells drawing strokewidth", strokeWidth);
	Dialog.addChoice("Wells drawing color", drawingColors, wellsDrawingColor);

	Dialog.show();

	bugedBioFormat = Dialog.getCheckbox();
	pyramidalResolution = Dialog.getChoice();
	pyramidalResolution *= 1;//convert to a number

	expectedWellDiameter = Dialog.getNumber();
	tolerance = Dialog.getNumber();
	rollingRadius = Dialog.getNumber();
	gaussianBlurSigma = Dialog.getNumber();
	segmentationGamma = Dialog.getNumber();
	intensityFactor = Dialog.getNumber();
	wellsThrMethodBF = Dialog.getChoice();
	wellSizeCorrectionFactor = Dialog.getNumber();

	gridSource = Dialog.getChoice();
	roiShape = Dialog.getChoice();
	centerRoisIndividually = Dialog.getCheckbox();
	outputBitDepth = Dialog.getChoice();
	outputGamma = Dialog.getNumber();
	wellsDrawingColor = Dialog.getChoice();
	strokeWidth = Dialog.getNumber();
	if (roiShape=="Circles") doAnalyzeDotShapes = false;
}

function getParams2() {
	Dialog.create("AdjustRoiGridToImage_And_Measure_"+version+"_params2");
	if (gridSource=="Disk (grid for #3)") {
		str = "                                                        ";
		Dialog.addMessage("Roi-grid from Disk:"+str);
		Dialog.addCheckbox("Flip horizontally",
			flipRoiGridHorizontally);
		Dialog.addNumber("Scale rois from grid by", roisScalingFactor);
	}
	else if (gridSource=="Computation") {
		Dialog.addMessage("Roi-grid computation:");
		Dialog.addCheckbox("Compute grid width & height from "+
			"detected wells", calculateGridDimensions);
		Dialog.addNumber("Width", gridWidth, 2, 7, "(physical units)");
		Dialog.addNumber("Height", gridHeight, 2, 7, "(physical units)");
		Dialog.addNumber("Columns", gridCols);
		Dialog.addNumber("Rows", gridRows);
		Dialog.addNumber("Rois Radius", roisRadius, 3, 6, "(physical units)");
	}
	Dialog.show();
	if (gridSource=="Disk (grid for #3)") {
		flipRoiGridHorizontally = Dialog.getCheckbox();
		roisScalingFactor = Dialog.getNumber();
	}
	else if (gridSource=="Computation)") {
		calculateGridDimensions = Dialog.getCheckbox();
		gridWidth = Dialog.getNumber();
		gridHeight = Dialog.getNumber();
		gridCols = Dialog.getNumber();
		gridRows = Dialog.getNumber();
		roisRadius = Dialog.getNumber();
	}
	if (roiShape=="Well_Outlines") getParams2b();
	else interpolateWellOutlines = false;
}

function getParams2b() {
	Dialog.create("AdjustRoiGridToImage_And_Measure_"+version+"_params2b");
	Dialog.addCheckbox("Interpolate well outlines", interpolateWellOutlines);
	Dialog.addNumber("Interpolation interval",
			interval, 0, 4, "pixels in pyramidal resolution image #3");
	Dialog.show();
		interpolateWellOutlines = Dialog.getCheckbox();
		interval = Dialog.getNumber();
}

function getParams3() {
	Dialog.create("AdjustRoiGridToImage_And_Measure_"+version+"_params3");
	Dialog.addCheckbox("Analyze dot shapes", doAnalyzeDotShapes);
	Dialog.addChoice("Threshold option", dotShapesAnalyzisThresholdOptions,
		dotShapesAnalyzisThresholdOption);
	Dialog.addChoice("Dots outline color", drawingColors, dotsDrawingColor);
	Dialog.addCheckbox("Hide intermediate images", hideImages);
	Dialog.addMessage("(Info: images are not hidden in dot shapes analyzis");
	Dialog.show();
	doAnalyzeDotShapes = Dialog.getCheckbox();
	dotShapesAnalyzisThresholdOption = Dialog.getChoice();
	dotsDrawingColor = Dialog.getChoice();
	hideImages = Dialog.getCheckbox();
	dbug = !hideImages;
}

function getParams4() {
	Dialog.create("AdjustRoiGridToImage_And_Measure_"+version+"_params4");
	Dialog.addMessage("Fluorescent dot shapes analyzis");
	Dialog.addNumber("Ignore particle if area < average well area /",
		minDotAreaRatio, 0, 5, "");
	if (dotShapesAnalyzisThresholdOption=="Fixed_Threshold") {
		positiveWellSignalRatio = 10;
	}
	else if (dotShapesAnalyzisThresholdOption=="AutoThreshold") {
		positiveWellSignalRatio = 100;
		Dialog.addChoice("Dots auto-threshold method",
			dotShapeThrMethods, dotShapeThrMethod);
	}
	Dialog.addNumber("A well is positive if mean >= mean of brightest well /",
			positiveWellSignalRatio, 0, 7, "");
/*
	Dialog.addNumber("Positive Well Signal Ratio",
			positiveWellSignalRatio, 2, 7, "");
*/
	Dialog.addChoice("Dots outline color", drawingColors, dotsDrawingColor);
	Dialog.show();
	minDotAreaRatio = Dialog.getNumber();
	if (dotShapesAnalyzisThresholdOption=="AutoThreshold") {
		dotShapeThrMethod = Dialog.getChoice();
	}
	positiveWellSignalRatio = Dialog.getNumber();
	dotsDrawingColor = Dialog.getChoice();
}

function printParams() {
	print("\nParams used for processing folder:");
	print("AdjustRoiGridToImage_And_Measure_"+version);
	print("bugedBioFormat = "+bugedBioFormat);
	print("roiShape = "+roiShape);

	print("expectedWellDiameter = "+expectedWellDiameter);
	print("tolerance = "+tolerance);
	
	print("wellSizeCorrectionFactor = "+wellSizeCorrectionFactor);
	print("gridSource = "+gridSource);
	print("gridCols = "+gridCols);
	print("gridRows = "+gridRows);
	print("calculateGridDimensions = "+calculateGridDimensions);
	print("roisRadius = "+roisRadius);
	print("flipRoiGridHorizontally = "+flipRoiGridHorizontally);
	print("roisScalingFactor = "+roisScalingFactor);
	print("gridWidth = "+gridWidth);
	print("gridHeight = "+gridHeight);
	print("pyramidalResolution = "+pyramidalResolution);
	print("rollingRadius = "+rollingRadius);
	print("gaussianBlurSigma = "+gaussianBlurSigma);
	print("segmentationGamma = "+segmentationGamma);
	print("intensityFactor = "+intensityFactor);
	print("interpolateWellOutlines = "+interpolateWellOutlines);
	print("interval = "+interval);

	print("outputBitDepth = "+outputBitDepth);
	print("outputGamma = "+outputGamma);
	print("wellsDrawingColor = "+wellsDrawingColor);
	print("strokeWidth = "+strokeWidth);
	print("doAnalyzeDotShapes = "+doAnalyzeDotShapes);
	print("dotShapesAnalyzisThresholdOption = "+
		dotShapesAnalyzisThresholdOption);
	print("dotShapeThrMethod = "+dotShapeThrMethod);
	print("minDotAreaRatio = "+minDotAreaRatio);
	print("positiveWellSignalRatio = "+positiveWellSignalRatio);
	print("dotsDrawingColor = "+dotsDrawingColor);
	print("wellsThrMethodBF = "+wellsThrMethodBF);

	print("dbug = "+dbug);
}

function processFolder() {
	print("\nprocessFolder()");
	//pixelSizeCorrection = 1;
	//if (pyramidalResolution==2) pixelSizeCorrection = 3;
	//else if (pyramidalResolution==1) pixelSizeCorrection = 9;
	pixelSizeCorrection = Math.pow(3, pyramidalResolution - 1);
	for (i=0; i<nimages; i++) {
		setBatchMode(true);
		if (dbug) setBatchMode(false);
		inputpath = dir1 + images[i];
		openImage(i);
		if (nImages<1) continue;
		inputImg = getImageID();
		img = getTitle();
		Stack.getDimensions(width, height, channels, slices, frames);
		print("\nProcessing "+(i+1)+" / "+nimages+" :");
		print(img);
		if (channels<2) {
			print("At least 2 channels required: skipped"); continue;
		}
		if (slices>1) {
			print("Stacks not accepted : skipped"); continue;
		}
		if (frames>1) {
			print("Time-lapse not accepted : skipped\n"+
			"To process time-lapse open as separate frames."); continue;
		}
		outputname = images[i]+"_#"+pyramidalResolution;
		npixels = width*height;
		getVoxelSize(pixelWidth, pixelHeight, depth, unit);
		print("pixelWidth = "+pixelWidth);
		print("pixelHeight = "+pixelHeight);
		if (bugedBioFormat && pyramidalResolution!=1)
			workaroundBioformatBug(pixelSizeCorrection);
		id = getImageID();
		if (!analyzeImage(id)) {
			if (isOpen(id)) {
				selectImage(id);
				close();
			}
			wellsDetectionFailed = false;
			print(img);
			print("Skipped (analyzis failed)");
			print("End analyzeImage(id)");
			print("Elapsed time: "+(getTime()-start)/1000+" s");
			continue;
		}
		close();
		print("Elapsed time: "+(getTime()-start)/1000+" s");
		selectWindow("Log");
		saveAs("Text", dir2+"Log_#"+pyramidalResolution+".txt");
		setBatchMode(false);
	}
	print("\nEnd processFolder()");
}

/* Creates a grid of circular Rois for Zeiss pyramidal resolution #3 image
 * ImageJ has problems with wand tool in large images
 * and with processing of large rois.
 * As a workaround, rois are created and processed at lowest resolution (#3).
 * After processing, the rois are scaled to fit the analyzis 
 * resolution chosen by the user if different from #3. */
function createCircularRoisGridForResolution3(imageID) {
	print("createCircularRoisGridForResolution3(imageID)");
	print("gridCols = "+gridCols);
	print("gridRows = "+gridRows);
	xStep = gridWidth/(gridCols-1);
	yStep = gridHeight/(gridRows-1);
	print("xStep = "+xStep);
	print("yStep = "+yStep);
	print("scanDirection = "+scanDirection);
	print("roisRadius = "+roisRadius+" "+unit);
	getGridCenterFromDotsArrayCorners();
	if (calculateGridDimensions) {
		fitSquare = true;
		getGridSizeFromDotsArrayCorners(fitSquare);
	}
	print("gridWidth = "+gridWidth);
	print("gridHeight = "+gridHeight);
	physicalUnits = true;
	createRoiGridForResolution3(gridCenterX, gridCenterY,
		gridCols, gridRows, xStep, yStep,
		scanDirection, roisRadius, physicalUnits);
	print("End createCircularRoisGridForResolution3(imageID)");
}

/*	Creates an grid of circular rois and sores them in the roiManager;
	centerX, centerY: coordinates of grid-center
	xStep, yStep: x and y periods
	scanSirection: "RiightToLeft" or "LeftToRight"
	roisRadius: radius  of the rois
	If !physicalUnits, lengths and positions must be passed in pixels */
function createRoiGridForResolution3(centerX, centerY, cols, rows,
		xStep, yStep, scanDirection, roisRadius, physicalUnits) {
	print("createRoiGridForResolution3()");
	factor = 1;
	if (pyramidalResolution==2) factor = 3;
	if (pyramidalResolution==1) factor = 9;
	roiManager("reset");
	//cx, cy, xs, ys: center coordinates and steps in pixels
	cx = centerX; cy = centerY;
	xs = xStep; ys = yStep;
	roisRadiusPixels = roisRadius / factor;
	if (physicalUnits) {//convert lengths and positions to pixels
		cx /= pixelWidth; cy /= pixelHeight;
		xs /= pixelWidth; ys /= pixelHeight;
		roisRadiusPixels /= sqrt(pixelWidth*pixelHeight);
		print("roisRadiusPixels = "+roisRadiusPixels);
	}
	if (factor>1) {//scale lengths down to fit resolution #3:
		xs /= factor; ys /= factor; cx /= factor; cy /= factor;
	}
	str = ""+cols*rows;
	digits = str.length;
	i=0;
	//roiCenterX, roiCenterY in pixels
	for (r=0; r<rows; r++) {
		roiCenterY = cy - ys*(rows-1)/2 + r*ys;
		if (scanDirection=="RightToLeft") {
			for (c=cols-1; c>=0; c--) {
				roiCenterX = cx - xs*(cols-1)/2 + c*xs;
				makeOval(roiCenterX-roisRadiusPixels,
					roiCenterY-roisRadiusPixels,
					2*roisRadiusPixels, 2*roisRadiusPixels);
				setSelectionName(String.pad(++i, digits));
				roiManager("add");
			}
		}
		else if (scanDirection=="LeftToRight") {
			for (c=0; c<cols; c++) {
				roiCenterX = cx - xs*(cols-1)/2 + c*xs;
				makeOval(roiCenterX-roisRadiusPixels,
					roiCenterY-roisRadiusPixels,
					2*roisRadiusPixels, 2*roisRadiusPixels);
				setSelectionName(String.pad(++i, digits));
				roiManager("add");
			}
		}
	}
	roiManager("deselect");
	Roi.remove;
	print("End createRoiGridForResolution3()");
}

function workaroundBioformatBug(pixelSizeCorrection) {
	print("workaroundBioformatBug("+pixelSizeCorrection+")");
	a = pixelSizeCorrection;
	setVoxelSize(pixelWidth*a, pixelHeight*a, depth, unit);
	getVoxelSize(pixelWidth, pixelHeight, depth, unit);
	print("Corrected pixelWidth = "+pixelWidth);
	print("Corrected pixelHeight = "+pixelHeight);		
	print("End workaroundBioformatBug("+pixelSizeCorrection+")");
}

/** Processes, segments and analyzes brightfield channel of image 'id'
	and stores the wells as Rois in RoiManager.
	Returns the ID of processed, potentially resized duplicate of Brightfield
	This is the critical part of the procedure. May fail if wells are irregular
	or have unequal intensities. */
function getWellsFromBrightfieldlAsRois(id) {
	print("getWellsFromBrightfieldlAsRois(id):");
	selectImage(id);
	Roi.remove;
	run("Remove Overlay");
	setOption("BlackBackground", true);
	Stack.setChannel(channels);
	run("Duplicate...", "title=processedBF");
	if (pyramidalResolution!=3) {
		w = width/Math.pow(3, 3-pyramidalResolution);
		h = height/Math.pow(3, 3-pyramidalResolution);
		run("Size...", "width="+w+" height="+h+
			" depth=1 constrain averageinterpolation=Bilinear"); 
	}
	if (rollingRadius>0) {
		rolling = rollingRadius/pixelWidth;//pixels
		run("Subtract Background...", "rolling="+rolling+" disable");
	}
	if (gaussianBlurSigma>1)//physical units
		run("Gaussian Blur...", "sigma="+gaussianBlurSigma+" scaled");
	run("Enhance Contrast", "saturated=0.10");
	run("8-bit");
	getStatistics(area, mean, min, max, std, histogram);
	run("Subtract...", "value="+min);
	factor = intensityFactor*255/(max-min+1);
	if (intensityFactor > 1)
		run("Multiply...", "value="+factor);
	if (segmentationGamma != 1)
		run("Gamma...", "value="+segmentationGamma);

	if (dbug) wait(1000);
	resetMinAndMax;
	setAutoThreshold(wellsThrMethodBF+" dark");
	if (dbug) wait(1000);
	roiManager("reset");
	run("Set Measurements...", "centroid display redirect=None decimal=3");
	mindRadius = expectedWellDiameter*(100-tolerance)/200;
	maxdRadius = expectedWellDiameter*(100+tolerance)/200;
	print("mindRadius = "+mindRadius+"    maxdRadius = "+maxdRadius);
	minSize = 3.14*mindRadius*mindRadius;
	maxSize = 3.14*maxdRadius*maxdRadius;
	print("minWellArea = "+minSize+"   maxWellArea = "+maxSize);
	run("Analyze Particles...",
		"size="+minSize+"-"+maxSize+" display clear include add");
	detectedWells = roiManager("count");
	print("Detected "+detectedWells+" wells");
	resetThreshold;
	n=gridRows*gridCols;
	if (detectedWells!=gridRows*gridCols) {
		print("An error occured in well detection: should find "+n+"wells");
		close();
		wellsDetectionFailed = true;
		print("End getWellsFromBrightfieldlAsRois(id):");
		return 0;
	}
	print("End getWellsFromBrightfieldlAsRois(id):");
	return getImageID();
}

function getGridCenterFromDotsArrayCorners() {
	print("getGridCenterFromDotsArrayCorners()");
	if (wellsDetectionFailed) {
		print("wellsDetectionFailed");
		print("End getGridCenterFromDotsArrayCorners()");
		return;
	}
	//corners coordinates are in physical units
	gridCenterX = (TopLeft[0]+TopRight[0]+BottomRight[0]+BottomLeft[0])/4;
	gridCenterY = (TopLeft[1]+TopRight[1]+BottomRight[1]+BottomLeft[1])/4;
	print("gridCenterX = "+gridCenterX+" "+unit);
	print("gridCenterY= "+gridCenterY+" "+unit);
	print("End getGridCenterFromDotsArrayCorners()");
}

//Doit servir a construire automatiquement la grille : utilser les dimensions
//et le centre pour construire une grille horizontale et la tourner en uilisnt
//l'angle calcule precedemment pour l'ajuster aux sommets du reseau de puits
//de l'image.
/** Uses TopLeft, TopRight, BottomRight and BottomLeft corners of dots-array
 * to compute its width, height and center. */
function getGridSizeFromDotsArrayCorners(fitSquare) {
	print("getGridSizeFromDotsArrayCorners(fitSquare)");
	if (wellsDetectionFailed) return;
	//corners coordinates
	TLx = TopLeft[0]; TRx = TopRight[0];
	TLy = TopLeft[1]; TRy = TopRight[1];
	BLx = BottomLeft[0]; BRx = BottomRight[0];
	BLy = BottomLeft[1]; BRy = BottomRight[1];

	//Average of 2 widths
	Txx = (TLx-TRx)*(TLx-TRx);
	Tyy = (TLy-TRy)*(TLy-TRy);
	TopWidth = sqrt(Txx+Tyy);
	Bxx = (BLx-BRx)*(BLx-BRx);
	Byy = (BLy-BRy)*(BLy-BRy);
	BottomWidth = sqrt(Bxx+Byy);
	gridWidth = (TopWidth+BottomWidth)/2;

	//Average of 2 heights
	Lxx = (TLx-BLx)*(TLx-BLx);
	Lyy = (TLy-BLy)*(TLy-BLy);
	LeftHeight = sqrt(Lxx+Lyy);
	Rxx = (TRx-BRx)*(TRx-BRx);
	Ryy = (TRy-BRy)*(TRy-BRy);
	RightHeight = sqrt(Rxx+Ryy);
	gridHeight = (LeftHeight+RightHeight)/2;

	if (fitSquare) {
		a = sqrt(gridWidth * gridHeight);
		gridWidth = gridHeight = a;
	}
	//print("gridWidth = "+gridWidth);
	//print("gridHeight = "+gridHeight);
	print("End getGridSizeFromDotsArrayCorners(fitSquare)");
}

/* Computes corners coordinates in physical units (microns) */
function getDotsArrayCornersFromRoiManager() {
	print("getDotsArrayCornersFromRoiManager()");
	if (wellsDetectionFailed) return;
	xmin = width*pixelWidth; ymin = height*pixelHeight;//TopLeft well
	xmax = 0; ymax = 0;//BottomRight well
	run("From ROI Manager");
	nDots = getValue("results.count");
	for (i=0; i<nDots; i++) {
		x = getResult("X", i);
		y = getResult("Y", i);
		if (x+y < xmin+ymin) {
			xmin=x; ymin=y;
		}
		if (x+y > xmax+ymax) {
			xmax=x; ymax=y;
		}
	}
	TopLeft[0]=xmin; TopLeft[1]=ymin;
	BottomRight[0]=xmax; BottomRight[1]=ymax;

	xmax=0; ymin=height*pixelHeight;//TopRight well
	xmin=width*pixelWidth; ymax=0;//BottomLeft well
	nDots = getValue("results.count");
	for (i=0; i<nDots; i++) {
		x = getResult("X", i);
		y = getResult("Y", i);
		if (x-y < xmin-ymax) {
			xmin=x; ymax=y;
		}
		if (x-y > xmax-ymin) {
			xmax=x; ymin=y;
		}
	}
	TopRight[0]=xmax; TopRight[1]=ymin;
	BottomLeft[0]=xmin; BottomLeft[1]=ymax;
	selectImage(processedBrightfield);
	setOption("Changes", false);
	if (dbug) wait(1000);
	print("End getDotsArrayCornersFromRoiManager()");
}

/**
 * Replaces circular Rois in roiManager by Rois resulting from
 * segmentation of the dots centered on circle centers
 * 'id': image on which wells are detected (processedBrightfield)
 * 'scaleFactor': factor by which detected wells are scaled to better fit real
 * wells */
function replaceGridCirclesByWellShapes(id, scaleFactor) {
	print("replaceGridCirclesByWellShapes()");
	if (!isOpen(id)) return false;
	selectImage(id);
	nrois = roiManager("count");
	Overlay.clear;
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		getSelectionBounds(x, y, w, h);//replace with robuster method
		run("Scale... ", "x=1.5 y=1.5 centered");
		resetMinAndMax;
		setAutoThreshold(wellsThrMethodBF+" dark");
		wait(50);
		doWand(x+w/2, y+h/2);//fails if bounds center outside selection
		run("Scale... ", "x="+scaleFactor+" y="+scaleFactor+" centered");
		//run("Interpolate", "interval=2 smooth adjust");

		if (interpolateWellOutlines) {
			run("Interpolate", "interval="+interval+" smooth adjust");
		}
		Overlay.addSelection;
	}
	resetThreshold();
	Roi.remove;
	replaceRoisInManagerByRoisFromOverlay();
	print("End replaceGridCirclesByWellShapes()");
	return true;
}

/** Refines positions of Rois in roiManager to fit the well centers
 * using processed brightfield
 * 'id' = processedBrightfield
 * For each Roi from Manager: 
 * - select
 * - enlarge to include the whole well.
 * - segment the image
 * - analyze particles -> X, Y (centroid)
 * - get coordinates X, Y from Results
 * - create circle centered on (X,Y) of radius roisRadius
 * - roiManager("update") etc */
function refineRoisPositionsIndividually(id) {
	print("refineRoisPositionsIndividually()");
	selectImage(id);
	run("Set Measurements...", "centroid display redirect=None decimal=3");
	r = roisRadius/sqrt(pixelWidth*pixelHeight);
	minSize = 3.14*r;
	minSize *= minSize;
	minSize *= 2;//if too small, more particles than wells
	maxSize = minSize*8;
	nrois = roiManager("count");
	Overlay.clear;
	factor = 1;
	if (pyramidalResolution==2) factor = 3;
	else if (pyramidalResolution==1) factor = 9;
	if (factor>1) r /= factor;
	print("minSize = "+minSize+"    maxSize = "+maxSize);
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		run("Scale... ", "x=1.5 y=1.5 centered");
		resetMinAndMax;
		setAutoThreshold(wellsThrMethodBF+" dark");
		run("Analyze Particles...", "size="+minSize+"-"+maxSize+
			" show=Nothing display clear include");
		if (getValue("results.count")!=1) {
			close();
			return false;
		}
		x = getResult("X", 0);
		y = getResult("Y", 0);
		x /= pixelWidth;
		y /= pixelHeight;
		if (factor>1) {x /= factor; y /= factor;}
		//print("x="+x+"  y="+y);
		makeOval(x-r, y-r, 2*r, 2*r);
		Overlay.addSelection;
	}
	resetThreshold();
	Roi.remove;
	replaceRoisInManagerByRoisFromOverlay();
	print("End refineRoisPositionsIndividually()");
	return true;
}

function replaceRoisInManagerByRoisFromOverlay() {
	roiManager("reset");
	run("To ROI Manager");
	renameRoisInManagerAsIncreasingNumbers();
}

function renameRoisInManagerAsIncreasingNumbers() {
	count = roiManager("count");
	for (i=0; i<count; i++) {
		roiManager("select", i);
		str = ""+count;
		digits = str.length;
		roiManager("rename", String.pad(i+1, digits));
	}
	roiManager("deselect");
	Roi.remove;
}

function analyzeImage(id) {
	print("analyzeImage(id)");
	sampleTilt = computeSampleTilt(id);
	if (wellsDetectionFailed || sampleTilt==NaN) return;
	//computeSampleTilt creates processedBrightfield at resolution #3
	if (gridSource=="Disk (grid for #3)") {
		loadRoiGrid(RoiGridPath);
		if (flipRoiGridHorizontally) roiGridHorizontalFlip();
	}
	else if (gridSource=="Computation") {
		createCircularRoisGridForResolution3(id);
	}
	aroundImageCenter = true;
	rotateRois(sampleTilt, aroundImageCenter);
	//Problem if (!calculateGridDimensions)
	translation = computeXYShift();
	tx = translation[0];
	ty = translation[1];
	translateRois(tx, ty);//Translate Roi-grid to fit well positions
	//at this stage, Rois are circular watever origin (disk or computation)
	if (roiShape=="Circles") {
		if (centerRoisIndividually) {
			//center circles from grid on wells
			if (!refineRoisPositionsIndividually(processedBrightfield)) {
				print("refineRoisPositionsIndividually failed");
				if (isOpen(id)) {
					selectImage(id);
					close();
				}
				return false;
			}
		}
		if (gridSource=="Disk (grid for #3)") {
			if (roisScalingFactor!=1) {
				//scaleRois(roisScalingFactor);
				replaceCircularRoisByScaledCircles(roisScalingFactor);
			}
		}
	}
	else if (roiShape=="Well_Outlines") {
		if (refineWellShapesFromFluo) {
			//not implemented
		}
		else {//get from BF
			if (!replaceGridCirclesByWellShapes(processedBrightfield,
					wellSizeCorrectionFactor)) {
				print("replaceGridCirclesByWellShapes failed");
				if (isOpen(id)) {
					selectImage(id);
					close();
				}
				return false;
			}
		}
	}
	run("Set Measurements...", "area mean standard min shape integrated"+
		" median redirect=None decimal=3");
	//run("Set Measurements...", "area mean standard min shape integrated"+
	//	" median display redirect=None decimal=3");
	selectImage(inputImg);
	scaleRoisToInputImageSize();
	formatRois();
	for (c=channels; c>=1; c--) {
		Stack.setChannel(c);
		measureChannel(id, c, outputname);
	}
	if (isOpen(processedBrightfield)) {
		selectImage(processedBrightfield);
		close();
	}
	if (doAnalyzeDotShapes) {
		selectImage(id);
		//channel = selectChannelForDotShapeAnalyzis(id);
		//analyzeDotShapes(id, channel);
		run("From ROI Manager");//copy well-rois to overlay for later recall
		roiManager("reset");
		for (c=1; c<channels; c++) analyzeDotShapes(id, c);
	}
	print("End analyzeImage(id)");
	return true;
}

function scaleRoisToInputImageSize() {
	factor = 1;
	if (pyramidalResolution==2) factor = 3;
	else if (pyramidalResolution==1) factor = 9;
	for (i=0; i<roiManager("count"); i++) {
		//Necessary, even if factor = 1
		roiManager("select", i);
		if (factor!=1) run("Scale... ", "x="+factor+" y="+factor);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/** Exposure times in increasing channel order
 * Returns the brightest fluorescence channel of image 'id' for which the
 * maximum pixel value is less than 2 thirds of saturation.
 * Channels are assumed to be in increasing intensity order, Last channel
 * to be brightfield. */
function selectChannelForDotShapeAnalyzis(id) {
	if (channels<3) return 1;
	selectImage(id);
	Stack.setChannel(channels-1);
	getStatistics(area, mean, min, max, std, histogram);
	if (max < 2*65535/3) return channels-1;
	for (c=channels-2; c>=1; c--) {
		Stack.setChannel(c);
		getStatistics(area, mean, min, max, std, histogram);
		if (max < 2*65535/3) return c;
	}
	return 1;//all channels saturated
}

/** Exposure times in decreasing channel order
 * Returns the brightest fluorescence channel of image 'id' for which the
 * maximum pixel value is less than 2 thirds of saturation.
 * Channels are assumed to be in decreasing intensity order,
 * Last channel to be brightfield. */
function selectChannelForDotShapeAnalyzis_2(id) {
	if (channels<3) return 1;
	selectImage(id);
	Stack.setChannel(1);
	getStatistics(area, mean, min, max, std, histogram);
	if (max < 2*65535/3) return 1;
	for (c=2; c<channels; c++) {
		Stack.setChannel(c);
		getStatistics(area, mean, min, max, std, histogram);
		if (max < 2*65535/3) return c;
	}
	return channels-1;//all channels saturated
}

function analyzeDotShapes(id, channel) {
	print("analyzeDotShapes(id, channel)");
	print("channel = "+channel);
	selectImage(id);
	Stack.setChannel(channel);
	setBatchMode(false);
	run("Duplicate...", " ");
	roiManager("reset");
	run("To ROI Manager");//move well-rois from overlay to Roi Manager
	nwells = roiManager("count");
	print("nwells = "+nwells);
	avgArea = 0;
	maxMax = 0;
	maxMean = 0;
	areas = newArray(nwells);
	maxs = newArray(nwells);
	means = newArray(nwells);
	wellX = newArray(nwells); wellY = newArray(nwells);
	maxW =0; maxH = 0;
	//wells statistics
	for (r=0; r<nwells; r++) {
		roiManager("select", r);
		Roi.getBounds(wellX[r], wellY[r], w, h);
		if (w>maxW) maxW = w;
		if (h>maxH) maxH = h;
		getStatistics(area, mean, min, max, std, histogram);
		areas[r] = area;
		maxs[r] = max;
		if (max>maxMax) maxMax = max;
		means[r] = mean;
		if (mean>maxMean) maxMean = mean;
		avgArea += area;
	}
	fontSize = Math.ceil(sqrt(maxW*maxH)/7);
	avgArea /= nwells;
	//minArea = avgArea/100;//particles smaller than minArea are ignored
	minArea = avgArea/minDotAreaRatio;
	print("maxMean = "+maxMean);
	print("nwells = "+nwells);
	run("Grays");
	roiManager("show none");
	run("From ROI Manager");
	print("Overlay.size = "+Overlay.size);
	wait(100);
	Overlay.setStrokeColor("black");
	roiManager("deselect");
	roiManager("delete");
	run("Set Measurements...",
		"area mean standard min center perimeter shape feret's"+
		" integrated median skewness redirect=None decimal=3");
	run("Clear Results");
	currentIndex = 0;
	totalParticles = 0;
	str = ""+nwells;
	digits = lengthOf(str);
	if (dotShapesAnalyzisThresholdOption=="Fixed_Threshold")
		setThreshold(maxMean/positiveWellSignalRatio, 65535);
	for (r=0; r<nwells; r++) {
/*
		if (maxs[r]<maxMax/positiveWellSignalRatio)
			minArea=avgArea*2;//exclude well from analyzis
*/
/*
		if (means[r]<maxMean/positiveWellSignalRatio)
			minArea=areas[r]*2;//exclude well from analyzis
*/
		Overlay.activateSelection(r);
		run("Scale... ", "x=1.15 y=1.15 centered");
		//wait(20);
		if (dotShapesAnalyzisThresholdOption=="AutoThreshold") {
			print("means["+(r+1)+"] = "+means[r]);
			if (means[r]<maxMean/positiveWellSignalRatio)
				minArea=areas[r]*2;//exclude well from analyzis
			setAutoThreshold(dotShapeThrMethod+" dark");
		}
		Overlay.activateSelection(r);
		wait(20);
		run("Analyze Particles...",
			"size="+minArea+"-Infinity display add composite");
		currentParticles = getValue("results.count")-totalParticles;
//		print("totalParticles = "+totalParticles);
		currentIndex = totalParticles;
		wellname = String.pad(r+1,digits);
		dotname = "0";
		for (i=0; i<currentParticles; i++) {
			dotname = ""+(i+1);
			currentIndex++;
			roiManager("select", currentIndex-1);
			roiManager("rename", wellname+"_"+dotname);
			selectWindow("Results");
			Table.set("Well", currentIndex-1, wellname);
			Table.set("Dot", currentIndex-1, dotname);
			Table.set("Image", currentIndex-1, outputname+"_chn"+channel);
			Table.update;
		}
		if (currentParticles==0) {
			makeRectangle(0, 0, 1, 1);
			setPixel(0, 0, 0);
			run("Measure");
			roiManager("Add");
			currentParticles = 1;
			currentIndex++;
			roiManager("select", currentIndex-1);
			roiManager("rename", wellname+"_"+dotname);
			selectWindow("Results");
			Table.set("Well", currentIndex-1, wellname);
			Table.set("Dot", currentIndex-1, dotname);
			Table.set("Image", currentIndex-1, outputname+"_chn"+channel);
			Table.update;
		}
		roiManager("deselect");
		Roi.remove;
		totalParticles += currentParticles;
//		print("Well_"+(r+1)+" : currentParticles = "+currentParticles);
	}
//	roiManager("show none");
	resetThreshold;
	Roi.remove;
	roiManager("deselect");
	RoiManager.setGroup(0);
	RoiManager.setPosition(0);
	roiManager("Set Color", dotsDrawingColor);
	roiManager("Set Line Width", strokeWidth);
	for (r=0; r<roiManager("count"); r++) {
		roiManager("select", r);
		roiManager("show none");
		Overlay.addSelection(dotsDrawingColor, strokeWidth);
		Overlay.drawLabels(false);
	}
	run("Fire");
	run("Invert LUT");
	Roi.remove;
	run("Enhance Contrast", "saturated=0.2");
	//resetMinAndMax;

	//setFont("SansSerif" , fontSize, "antialiased bold");
	setFont("SansSerif" , fontSize, "antialiased");
	setColor(0, 0, 0);
 	for (i=0; i<nwells; i++) {
		wellname = String.pad(i+1,digits);
		Overlay.drawString(wellname, wellX[i], wellY[i]);
	}

	saveAs("ZIP", dir2+outputname+"_chn"+channel+"_shapes.zip");
	close();
	selectWindow("Results");
	saveAs("Results", dir2+outputname+"_chn"+channel+"_shapes.csv");
	print("End analyzeDotShapes(id, channel)");
	if (dbug) setBatchMode(true);
}

/** Computes the angle by which rotate the Roi-grid to fit the dots
	in the brightfield channel of image to be analyzed */
function computeSampleTilt(imageID) {
	print("computeSampleTilt(imageID)");
	processedBrightfield = getWellsFromBrightfieldlAsRois(imageID);
	if (wellsDetectionFailed) return NaN;
	diagonalAngle = 45;
	if (gridRows!=gridCols)
		diagonalAngle = Math.atan(gridRows/gridCols);//to be verified
	getDotsArrayCornersFromRoiManager();
	fitSquare = true;
	run("Remove Overlay");
	print("TopLeftX="+TopLeft[0]+"  TopLeftY="+TopLeft[1]);
	print("BottomRightX="+BottomRight[0]+"  BottomRightY="+BottomRight[1]);
	//makeSelection("angle",newArray(x1,x2,x3),newArray(y1,y2,y3));
	makeSelection("angle",newArray(BottomRight[0],TopLeft[0],width*pixelWidth),
		newArray(BottomRight[1],TopLeft[1],TopLeft[1]));
	run("Clear Results");
	run("Measure");
	tilt1 = getResult("Angle", 0) - diagonalAngle;
	print("tilt1="+tilt1);
	//2nd measurement of tilt, to be averaged with 1st:
	run("Remove Overlay");
	print("TopRightX="+TopRight[0]+"  TopRightY="+TopRight[1]);
	print("BottomLeftX="+BottomLeft[0]+" BottomLeftY="+BottomLeft[1]);
	x1 = width*pixelWidth; x2 = BottomLeft[0]; x3 = TopRight[0];
	makeSelection("angle",newArray(width*pixelWidth,BottomLeft[0],TopRight[0]),
		newArray(BottomLeft[1],BottomLeft[1],TopRight[1]));
	run("Clear Results");
	run("Measure");
	tilt2 = diagonalAngle - getResult("Angle", 0);
	print("tilt2="+tilt2);
	print("End computeSampleTilt(imageID)");
	return (tilt1+tilt2)/2;
}

/** Returns the translation to be applied to the Roi-grid after it has been
	rotated around the image center to fit the dots in brightfield image.
	Uses the four corners of the grid for better precision
	Components of translation are expressed in pixels */
function computeXYShift() {
	print("computeXYShift()");
	selectImage(processedBrightfield);
	getPixelSize(unit, pixWidth, pixHeight);
	if (nDots!=gridRows*gridCols) {
		print("An error occured in wells detection");
		print("tx="+0);
		print("ty="+0);
		print("End computeXYShift()");
		return newArray(0,0);
	}
	roiManager("select", 0);//TopLeft
	getSelectionBounds(x0, y0, w0, h0);
	Roi.remove;
	//Corner coordinates are returned in physical units
	//while getSelectionBounds returns values in pixels
	tx0 = TopLeft[0]/pixWidth - (x0+w0/2);
	ty0 = TopLeft[1]/pixHeight - (y0+h0/2);
	print("tx0="+tx0);
	print("ty0="+ty0);

	rows = sqrt(nDots);
	roiManager("select", rows-1);//TopRight
	getSelectionBounds(x1, y1, w1, h1);
	Roi.remove;
	tx1 = TopRight[0]/pixWidth - (x1+w1/2);
	ty1 = TopRight[1]/pixHeight - (y1+h1/2);
	print("tx1="+tx1);
	print("ty1="+ty1);

	roiManager("select", nDots-1);//BottomRight
	getSelectionBounds(x2, y2, w2, h2);
	Roi.remove;
	tx2 = BottomRight[0]/pixWidth - (x2+w2/2);
	ty2 = BottomRight[1]/pixHeight - (y2+h2/2);
	print("tx2="+tx2);
	print("ty2="+ty2);

	roiManager("select", nDots-rows);//BottomLeft
	getSelectionBounds(x3, y3, w3, h3);
	Roi.remove;
	tx3 = BottomLeft[0]/pixWidth - (x3+w3/2);
	ty3 = BottomLeft[1]/pixHeight - (y3+h3/2);
	print("tx3="+tx3);
	print("ty3="+ty3);

	//average to increase precision
	tx = (tx0+tx1+tx2+tx3)/4;
	ty = (ty0+ty1+ty2+ty3)/4;
	print("tx="+tx);
	print("ty="+ty);

	print("End computeXYShift()");
	return newArray(tx,ty));
}

/** Creates a copy of 'chn' with the adjusted Roi-grid and saves it to  dir2.
	Measures fluorescence from 'chn' in adjusted Rois-grid (chn < nchannels);
	Saves results in dir2 */
function measureChannel(imageID, chn, outputname) {
	run("Clear Results"); 
	selectImage(imageID);
	tit = getTitle();
	Stack.getDimensions(w, h, nchn, depth, nframes);
	Stack.setChannel(chn);
	roiManager("remove slice info");
	roiManager("Set Line Width", strokeWidth);
	roiManager("deselect");
	run("Duplicate...", " ");
	run("Fire");
	resetMinAndMax();
	if (outputBitDepth=="8-bit") run("8-bit");
	if (outputGamma!=1) run("Gamma...", "value="+outputGamma);
	run("From ROI Manager");
	run("Overlay Options...", "stroke=red width="+30+" fill=none show");
	run("Labels...", "color="+wellsDrawingColor+" font=16 bold show use");
	roiManager("Show None");
	saveAs("zip", dir2+outputname+"_chn"+chn+".zip");
	close();
	if (chn==nchn) return;//don't measure last channel (brightfield)
	//run("Clear Results"); 
	roiManager("measure");
	selectWindow("Results");
	for (r=0; r<getValue("results.count"); r++)
		Table.set("Image", r, outputname+"_chn"+chn);
	saveAs("Results", dir2+outputname+"_chn"+chn+".csv");
}

function filterList(list, extension) {
	nfiles = list.length;
	list2 = newArray(nfiles);
	j=0;
	for (i=0; i<nfiles; i++) {
		if (!endsWith(list[i], extension)) continue;
		list2[j++] = list[i];
	}
	return Array.trim(list2, j);
}

function openImage(index) {
	path = dir1 + images[index];
	run("Bio-Formats Importer", "open=["+path+"] color_mode=Colorized "+
		"rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_"+
		pyramidalResolution);
	inputImg = getImageID();
}

/** Replaces Rois in roiManager by circles
	of radius the radius of 1st Roi multiplied by 'scale' */
function replaceCircularRoisByScaledCircles(scale) {
	//scaleRois(roisScalingFactor);
	roiManager("select", 0);
	getSelectionBounds(xx, yy, ww, hh);
	radius = sqrt(ww*hh)/2;
	radius *= scale;
	replaceRoisByCircles(radius);
}

/** Replaces Rois in roiManager by circles */
function replaceRoisByCircles(radius) {
	nrois = roiManager("count");
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		Roi.getBounds(bx, by, bw, bh);
		cx = bx+bw/2;
		cy = by+bh/2;
		makeOval(cx-radius, cy-radius, 2*radius, 2*radius);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/** Poor precision for small Rois
	In case of circular Rois, use replaceRoisByCircles(radius) instead */
function scaleRois(scale) {
	nrois = roiManager("count");
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		run("Scale... ", "x="+scale+" y="+scale+" centered");
		roiManager("update");
		run("Fit Circle");//result is not really a circle
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/**
 * Rotates all rois in roiManager by 'angle' degrees:
 * around image center if aroundImageCenter is true;
 * aroud roi center otherwise.
	//test-code:
		aroundImageCenter = true;
		angle = 12; //degrees
		rotateRois(12, aroundImageCenter);
 */
function rotateRois(angle, aroundImageCenter) {
	nrois = roiManager("count");
	param = "";
	if (aroundImageCenter) param = "rotate ";
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		run("Rotate...", param+" angle="+angle);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/** Translates all rois in roiManager by 'tx', 'ty'
	//test-code:
		tx=10; ty=20;
		translateRois(tx, ty);
 */
function translateRois(tx, ty) {
	nrois = roiManager("count");
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		getSelectionBounds(x, y, w, h);
		Roi.move(x+tx, y+ty);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

function loadRoiGrid(path) {
	roiManager("reset");
	roiManager("Open", path);
	roiManager("deselect");
	Roi.remove;
}

function formatRois() {
	for (i=0; i<roiManager("count"); i++) {
		roiManager("select", i);
		roiManager("Set Color", wellsDrawingColor);
		roiManager("Set Line Width", strokeWidth);
	}
	roiManager("deselect");
	Roi.remove;
}

/* Flips Roi-grid from Manager horizontally
 * Assumes grid is rectangular */
//test-code:
//roiGridHorizontalFlip();
function roiGridHorizontalFlip() {
	print("roiGridHorizontalFlip");
	print("gridCols = "+gridCols);
	print("gridRows = "+gridRows);
	nrois = roiManager("count");
	if (nrois<2) return;
	newNames = flipRoiNamesHorizontally();
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		roiManager("rename", newNames[i]);
		roiManager("update");
	}
	roiManager("deselect");
	roiManager("sort");
	Roi.remove;
}

/* Renames rois from a rectangular grid to invert horizontal scan direction */
//test-code
//columns = 5; rows = 5;
//flipRoiNamesHorizontally();
function flipRoiNamesHorizontally() {
	//print("\nflipRoiNamesHorizontally");
	print("gridCols = "+gridCols);
	print("gridRows = "+gridRows);
	nrois = roiManager("count");
	if (nrois<2) return;
	rows = gridRows;
	cols = gridCols;
	if (nrois!= cols*rows) return;
	str = ""+nrois;
	digits = str.length;
	newNames = newArray(nrois);
	i=0;
	for (r=0; r<rows; r++) {
		for (c=cols-1; c>=0; c--) {
			newNum = c+1+r*rows;
			//print("newNum = "+newNum);
			newNames[i++] = String.pad(newNum, digits);
		}
	}
	//for (i=0; i<newNames.length; i++) print(newNames[i]);
	return newNames;
}

// 80 characters 789 123456789 123456789 123456789 123456789 123456789 123456789