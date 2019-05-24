/** 
 * macro "MetamorphFilesFolderToHyperstacks_"
 * Author : Marcel Boeglin, July 2018 - May 2019
 * 
 * ¤ Opens Metamorph multi-position time-series z-stacks of up to 7
 *   channels from input folder and saves them as hyperstacks to 
 *   output folder.
 * ¤ Only TIFF and STK files are processed.
 * ¤ Channel colors are derived automatically from filennames but 
 *   can be changed by the user.
 *   For example, channels containing RFP, GFP, Dapi or BF in their
 *   names are assumed to be respectively red, green, blue or gray.
 * ¤ Image files for which no series name was found are skipped.
 * ¤ Calibrates output images in X, Y, Z and T if calibration data
 *   are found
 * ¤ Does optional maximum z-projection of input files and 
 *   color balance of output files.
 * ¤ In case of heterogeneous z-dimensions between channels and 
 *   'Do z-projection' is unchecked, single-section channels
 *   are transformed to z-stacks having same depth as channels
 *   acquired as z-stacks by duplicating the single-section.
 * ¤ Series handling dialog is not displayed if larger than screen 
 *   (happens if the folder contains more series than can be added
 *   as checkboxes in a dialog).
 * 
 * Known problems:
 * ¤ Temporal calibration fails if timelapse crosses year.
 *   --o-> frame interval = 0 or is false
 * ¤ Channels handling dialog boxes may be larger than screen if the
 *   folder contains a large number of series having different channel
 *   sequences.
*/

var macroName = "MetamorphFilesFolderToHyperstacks";
var version = "42x";
var author = "Author: Marcel Boeglin 2018-2019";
var msg = macroName+"\nVersion: "+version+"\n"+author;
var info = "Created by "+macroName+"\n"+author;
var features = "Opens  input folder  image series consisting  in up"+
	"\nto 7 channels  multi-position  time-series  z-stacks"+
	"\nnamed according to Metamorph dimensions order"+
	"\nand saves them as hyperstacks to output folder."+
	"\nCalibrates output images if metadata can be read."+
	"\nInput folder should contain only original images.";
var compositeColors = newArray("red", "green", "blue", "gray",
	"cyan", "magenta", "yellow");
var compositeChannels = newArray("c1", "c2", "c3", "c4", "c5", "c6", "c7");
var projectionTypes = newArray("Average Intensity",
								"Max Intensity",
								"Min Intensity",
								"Median",
								"Sum Slices");

var colors = newArray("Red", "Green", "Blue", "Grays",
			"Cyan", "Magenta", "Yellow");


///////////////////////////////////////////////////////////
//To change dialog defaults, modify variables below:

//Add your channel determinants to arrays below to auto-assign color.
//If a determinant appears in different colors, only first one is used.
var redDeterminants = newArray("543", "555", "561", "594", "CY3", "Y3",
		"DsRed", "mCherry", "N21", "RFP", "TX2");
var greenDeterminants = newArray("GFP", "FITC", "488", "491");
var blueDeterminants = newArray("405", "CFP", "CY5", "DAPI", "HOECHST", "Y5",
		"633", "642", "647");
var grayDeterminants = newArray("BF", "DIC", "PH", "TL", "TRANS");
//var grayDeterminants = newArray("BF", "DIC", "PH", "TL", "TRANS", "642");
var cyanDeterminants = newArray("CFP");
var magentaDeterminants = newArray("CY5", "Y5");
var yellowDeterminants = newArray("YFP");

var XYZUnitChoices = newArray("pixel", "nm", "micron", "um", "µm", 
								"mm", "cm", "m");
var TUnitChoices = newArray("ms", "s", "min", "h");

var allSeriesSameXYZTCalibrations;
var calibrationOption;
var calibrationOptions = newArray("Don't calibrate anything", 
		"Same calibrations for all series",
		"Different calibrations for each series",
		"Get calibration from metadata");

var XYCalibrations, ZCalibrations, TimeIntervals;
var XYZUnits, TUnits;

/** if true, channels for which only 1st timepoint was recorded are ignored */
var ignoreSingleTimepointChannels = true;

//var autoscale = true;

/** % saturated pixels for channels in composite output images*/
var compositeChannelSaturations =  newArray(0.05,		//red
											0.05,		//green
											0.05,		//blue
											0.0,		//gray
											0.01,		//cyan
											0.01,		//magenta
											0.01);		//yellow

var doSeries;//array of dim nSeries
var letMeChooseSeries = true;
var noChannelDependentBinning = true;
var doZproj = true;
var doZprojsByDefault = true;
var to32Bit = false;
var firstSlice = -1, lastSlice = -1;
var oneOutputFilePerTimePoint = false;
var createFolderForEachOutputSeries = false;//palliatif bug Imaris
//End of variables to be changed to modify dialog defaults.
///////////////////////////////////////////////////////////


//Depuis 41j :
//Variables tableaux 2D pour chaque serie sous forme de chaines de caracteres
//separees par des virgules. Ex. : 
//seriesChannelSequences() = newArray(nSeries);
//seriesChannelSequences()[0] = "_w1CY3,_w2FITC,_w3DAPI";
//etc.
//Pour chaque serie, le tableau des canaux est reconstruit en utilisant
//la methode toArray(arrayStr, separator) qui renvoie dans le cas precedent :
//seriesChannels = {"_w1CY3", "_w2FITC", "_w3DAPI"};

/** Array of filenames separated by "'" for each series */
var seriesFilenamesStr;
/** Array of fileNumbers for each series */
var seriesFileNumbers;
//var nFilesInSeries;//c'est deja une variable locale

/** Array of channelnames separated by "," for each series */
var seriesChannelSequences;
/** Array of series channels Numbers */
var seriesChannelNumbers;

/** Array of length the number of different channel sequences;
* its elements are _w1, _w2, ... separated by "," */
var channelSequences;

/** Array of length the number of different channel sequences;
 * seriesWithSameChannels[i] = names of the series having channelSequences[i],
 * separated by "," */
var seriesWithSameChannels;

/** Position numbers for each series; array of same length as seriesNames */
var positionNumbers;//a remplacer par supra


/** Array of timepoint strings separated by "," for each series */
//PEUT-ETRE INUTILE mais peut servir a voir s'il manque des temps intermediaires
//dans certaines series (mais pas pour certains canaux)
var seriesTimePointsStr;
/** Array of series timePoints Numbers */
var seriesTimePointNumbers;
/** isSingleTimepointChannel est a determiner pour chaque serie et chaque canal
 *  au moment du traitement du dossier
 * si isSingleTimepointChannel est vrai pour une position, il devrait l'etre
 * pour toutes les positions de la meme serie*/
var isSingleTimepointChannel;


/** maxImageWidhs, maxImageHeights for each series; some channels may have
 *  been acquired with a binning of 2 or 4;
 *  These arrays allow to not break processing if 1st images of a series are 
 *  missing or if a channel has a different binning.
 *  These arrays have same length as seriesNames */
var seriesCompleteness;
var imageTypes, maxImageWidhs, maxImageHeights, maxImageDepths;

//pour le moment on utilise ca :
var	imageTypes;
var	imageWidhs;
var	imageHeights;
var	imageDepths;

/** min and max position number in filtered file list */
var minPosition, maxPosition;

/** userPositions: array(maxPosition - minPosition)
 *  position names of positions choosen by user */
var userPositions = newArray(1);

/** String array of all positions series by series. 
 * Array elements are _s1, _s2, ..., _sS1,  _s1, s2, ..., _sS2, ...
 * sS1 is positions number of series 1,
 * sS2 positions number of series 2 etc.*/
var positionsSeriesBySeries;
/** Boolean arrays positionExists, isCompletePosition (series by series). 
 * 'exists' means found at least one file with '_s...' in its name;
 * 'complete' means no File (c, t) is missing in series for this position. 
 * These arrays have same length as positionsSeriesBySeries. */
var positionExists, isCompletePosition;
/**String array: userPositions, detailed series by series */
var userPositionsSeriesBySeries;


/** doChannelsFromSequences: array of length the number of channel sequences */
var doChannelsFromSequences;
/** doZprojForChannelSequences: array of length the number of channel
* sequences */
var doZprojForChannelSequences;
/** projTypesForChannelSequences: array of length the number of channel 
* sequences; retrieve elements using toArray(arrayStr, separator) */
var projTypesForChannelSequences;

/** seriesChannelGroups: array of length nSeries
* values are the channelGroupID (0, 1, channelGroupsNumber) 
* to which belongs each series */
var seriesChannelGroups;

//NOUVELLES VARIABLES, pour channelColorsAndSaturationsDialog():
var channelSequencesColors;
var channelSequencesSaturations;


var fileFilter = "";
var excludingFilter = "";
var channelSuffix = "_w";
var positionSuffix = "_s";
var timeSuffix = "_t";
var dir1, dir2, list;
var allChannels, allChannelColors, allChannelIndexes, allOutputColors;
var seriesNames, channels, projTypes;
var nChn, nPositions, nFrames, depth;
var doChannel;
var activeChannels;//number of channels to be processed in current series
var nSeries;
var channelSaturations;

var imageInfo;
var pixelSizes, xyUnits;
var pixelSize, xyUnit;
var voxelWidths, voxelHeights, voxelDepths;
var voxelWidth, voxelHeight, voxelDepth;
var xUnits, yUnits, zUnits;
var xUnit, yUnit, zUnit;

var sliceNumber, ZInterval, ZUnit;

var frameInterval, frameIntervals;
var userPixelSize, userVoxelDepth, userLengthUnit;
var userFrameInterval, userTUnit;
var meanFrameInterval;
var TUnit;
var atLeastOneTimeSeries;
var foundAcquisitionTime;
var acquisitionDay, acquisitionTime;
var acquisitionTimes = newArray(2);
var acquisitionDays = newArray(2);
var askForCalibrationsAndUnits;
var channelColorIndexes;

var pluginName = "tiff_tags.jar";
var tiff_tags_plugin_installed = false;

requires("1.52g");
//askForCalibrationsAndUnits = isKeyDown("alt");
//print("askForCalibrationsAndUnits = "+askForCalibrationsAndUnits);
//setKeyDown("none");

var seriesWithSameChannels;

execute();

/** returns array of strings contained in arrayStr 
 * and separated by 'separator' 
 * where arrayStr is a single string
 */
function toArray(arrayStr, separator) {
	//print(arrayStr);
	if (arrayStr=="") return newArray(1);
	a = split(arrayStr, "("+separator+")");
	return a;
}

var fileFound = false;
var count3 = 1;
function fileExists(dir, filename) {
	//print("filename = "+filename);
	fileFound = false;
	searchFile(dir, filename);
	return fileFound;
}

function searchFile(dir, filename) {
	//print("searchFile(dir, filename)");
	//print("dir = "+dir);
	//print("filename = "+filename);
	list3 = getFileList(dir);
	for (i=0; i<list3.length; i++) {
		if (File.isDirectory(""+dir+list3[i])) {
			searchFile(""+dir+list3[i], filename);
		}
		else {
			//print((count3++) + ": " + dir + list3[i]);
			if (list3[i] == filename) {
				fileFound = true;
			}
			//print("fileFound = "+fileFound);
		}
	}
}

function findPlugin(pluginName) {
	print("\nfindPlugin("+pluginName+")");
	pluginsDir = getDirectory("plugins");
	return fileExists(pluginsDir, pluginName);
}

function getMinAndMaxPosition(filenames, seriesName) {
	mp = isMultiPosition(filenames, seriesName);
	if (!mp) return 1;
	ts = isTimeSeries(filenames, seriesName);
	positionDelimiter = ".";
	if (ts) positionDelimiter = "_t";
	nFiles = getFilesNumber(seriesName);
	//print("nFiles in series = "+nFiles);
	j = 0;
	minPosition = 1000000;
	maxPosition = 1;
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			splittenName = split(name, "(_s)");
			str = splittenName[splittenName.length-1];//last element
			posStr = substring(str,0,indexOf(str,positionDelimiter));
			n = parseInt(posStr);
			maxPosition = maxOf(maxPosition, n);
			minPosition = minOf(minPosition, n);
			j++;
		}
		if (j==nFiles) break;
	}
}

function isMultiPosition(filenames) {
	nFiles = filenames.length;
	for (i=0; i<nFiles; i++) {
		name = filenames[i];
		//name = seriesNameLessFilename(name, seriesName);
		//if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			return true;
		}
	}
	return false;
}

function isSeriesFilter(fileFilter) {
	if (matches(fileFilter, "_w\\d{1,2}.*")) return false;
	if (matches(fileFilter, "_s\\d{1,3}_.*")) return false;
	if (matches(fileFilter, "_s\\d{1,3}\\..*")) return false;
	if (matches(fileFilter, "_t\\d{1,5}_.*")) return false;
	if (matches(fileFilter, "_t\\d{1,5}\\..*")) return false;
	return true;
}

function isWaveFilter(fileFilter) {
	if (matches(fileFilter, "_w\\d{1,3}.*")) return true;
	return false;
}

function isPositionFilter(fileFilter) {
	if (matches(fileFilter, "_s\\d{1,3}_")) return true;
	if (matches(fileFilter, "_s\\d{1,3}\\.")) return true;
	return false;
}

function isTimeFilter(fileFilter) {
	if (matches(fileFilter, "_t\\d{1,5}_")) return true;
	if (matches(fileFilter, "_t\\d{1,5}\\.")) return true;
	return false;
}

function isExtensionFilter(fileFilter) {
	s = toLowerCase(fileFilter);
	if (matches(s, "\\.tif")) return true;
	if (matches(s, "\\.stk")) return true;
	return false;
}

function execute() {
	print("\\Clear");
	//askForCalibrationsAndUnits = isKeyDown("alt");
	//print("askForCalibrationsAndUnits = "+askForCalibrationsAndUnits);
	//setKeyDown("none");
	getDirs();
	print(msg+"\n ");
	print(features);
	startTime = getTime();
	fileFilterAndCalibrationParamsDialog();
	tiff_tags_plugin_installed = findPlugin("tiff_tags.jar");
	if (tiff_tags_plugin_installed)
		print("tiff_tags.jar is installed");
	else
		print("To calibrate Z-interval automatically install tiff_tags plugin");
	list = getFiles(dir1);
	print("File list:");
	for (i=0; i<list.length; i++) print(list[i]);
	//keep only TIFF & STK files matching fileFilter but not excludingFilter
	list = filterList(list, fileFilter, excludingFilter);
	seriesNames = getSeriesNames(list);
	//print("execute() : nSeries = "+nSeries);
	doSeries = newArray(nSeries);
	for (i=0; i<nSeries; i++) doSeries[i] = true;
	//doSeries[0] = true;
	if (nSeries>1 && letMeChooseSeries) {
		displaySeriesNamesDialog();
	}
	list = reduceListToSelectedSeries(list);
	nSeries = seriesNames.length;

	print("\nSelected series (seriesNames filtered by seriesNames):");
	for (i=0; i<seriesNames.length; i++) {
		print(seriesNames[i]);
		print("doSeries = "+doSeries[i]);
	}
//	print("\nseries filtered filenames list:");
//	for (i=0; i<list.length; i++) {
//		print(list[i]);
//	}
//	print("series filtered filenames list: END");

	seriesFilenamesStr = getSeriesFilenames(list);
	seriesChannelSequences = getSeriesChannelSequences();
	channelSequences = getChannelSequences(seriesChannelSequences);
	seriesWithSameChannels = groupSeriesHavingSameChannelSequence();
	assignChannelGroupToSeries();
	print("");
	nSeries = seriesNames.length;
	getImageTypes_MaxWidhs_MaxHeights();
	//getSeriesImageTypes_Widhs_Heights();//remplace par supra
	//getSeriesCompleteness_imageTypes_MaxImageWidhsAndHeights();//ANCIEN
	for (i=0; i<nSeries; i++) {
		print("seriesChannelGroups["+i+"] = "+seriesChannelGroups[i]);
	}

//	print("execute() :");
	seriesFileNumbers = getSeriesFileNumbers(seriesFilenamesStr);
	print("");
	for (i=0; i<seriesFileNumbers.length; i++) {
		print("seriesFileNumbers["+i+"] = "+seriesFileNumbers[i]);
	}
	print("\nTIFF and STK image list to be processed:");
	for (i=0; i<list.length; i++) print(list[i]);
	//getSeriesCalibrationOptions();
	atLeastOneTimeSeries = foundAtLeastOneTimeSeries();

	printParams();

	channelGroupsHandlingDialog();
	channelColorsAndSaturationsDialog();

	filterExtensions = isExtensionFilter(fileFilter);
	//print("filterExtensions = "+filterExtensions);
	nSeries = seriesNames.length;
	positionNumbers = newArray(nSeries);
	maxPositions = 1;
	nPos = 1;
	for (i=0; i<nSeries; i++) {
		//print("doSeries["+i+"] = "+doSeries[i]);
		fnames = split(seriesFilenamesStr[i], ",");
		n = getPositionsNumber(fnames, seriesNames[i]);//renvoie val fausse
		positionNumbers[i] = n;
		//print("positionNumbers["+i+"] = "+positionNumbers[i]);
		if (n > maxPositions) maxPositions = n;
		if (doSeries[i] && n>nPos) nPos = n;
	}
	//print("nPos = "+nPos);
	//print("maxPositions = "+maxPositions);
	findPositionsSeriesBySeries(list);
	positionsSeriesBySeriesDialog(list);

//	startTime = getTime();
	processFolder();
	finish();
}

/** Asks for each series if is to be precessed or not
 * Problem if more series than maximum number of checkboxes 
 * that can be dispayed in a single dialog window */
function displaySeriesNamesDialog() {
	len = 0;
	for (i=0; i<nSeries; i++) {
		len2 = lengthOf(seriesNames[i]);
		if (len2>len) len = len2;
	}
	dialogBorderWidth = 10;//pixels
	charWidth = 8;//approximmative mean character width, pixels
	minimalCheckboxWidth = 22;//pixels
	maxCols = floor((screenWidth - 2 * dialogBorderWidth) /
			(len * charWidth + minimalCheckboxWidth));
	print("displaySeriesNamesDialog() : maxCols = "+maxCols);
	Dialog.create(macroName);
	Dialog.addMessage("Process series:");
	unavailableHeight = 144;//dialog height if no series to be displayed
	checkboxHeight = 23;
	availableHeight = screenHeight - unavailableHeight;
	maxRows = floor(availableHeight/checkboxHeight) - 1;
	columns = 1;
	if (nSeries<maxRows)
		for (i=0; i<nSeries; i++)
			Dialog.addCheckbox(seriesNames[i], true);
	else {
		rows = maxRows;
		columns = floor(nSeries/rows)+0;
		print("maxRows = "+maxRows);
		print("rows = "+rows);
		print("columns = "+columns);
		while (columns*rows<nSeries) columns++;
		print("columns = "+columns);
		while (columns*rows>nSeries+columns) rows--;
		print("rows = "+rows);
		print("nSeries = "+nSeries);
		print("columns * rows  = "+columns*rows);//must be >= nSeries
		Dialog.addCheckboxGroup(rows, columns, seriesNames, doSeries);
	}
	if (columns>maxCols) {
		if (!getBoolean("Cannot display "+nSeries+
				" series names in dialog box"+
				"\nYes to process all series, No or Cancel to abort."))
			exit();
	}
	Dialog.show();
	for (i=0; i<nSeries; i++) {
		doSeries[i] = Dialog.getCheckbox();
	}
	for (i=0; i<nSeries; i++) {
		print("Series "+i+" : "+seriesNames[i]+
				" : doSeries["+i+"] = "+doSeries[i]);
	}
}

/** Calculates image widths, heights and types of selected series
 * Assumes all images in a series have same type, width and height
 * Opens first image of each series and gets type, width and height */
function getSeriesImageTypes_Widhs_Heights() {
	print("\nnSeries = "+nSeries);
	imageTypes = newArray(nSeries);
	imageWidhs = newArray(nSeries);
	imageHeights = newArray(nSeries);
	imageDepths = newArray(nSeries);//POUR LE MOMENT ON N'UTILISE PAS
	for (i=0; i<seriesFilenamesStr.length; i++) {
		fnames = seriesFilenamesStr[i];
		fnamesArray = split(fnames, "(,)");
		setBatchMode(true);
		bitdepth = 16;
		for (j=0; j<fnamesArray.length; j++) {
			print("fnamesArray["+j+"] = " + fnamesArray[j]);//juste
			path = dir1 + fnamesArray[j];
			if (!File.exists(path)) continue;//ne devrait jamais etre le cas
			open(path, 1);
			bitdepth = bitDepth();
			width = getWidth();
			height = getHeight();
			close();
			break;
		}
		if (bitdepth==8) imageTypes[i] = "8-bit";
		else if (bitdepth==16) imageTypes[i] = "16-bit";
		else if (bitdepth==24) imageTypes[i] = "RGB";
		imageWidhs[i] = width;
		imageHeights[i] = height;
		print("imageWidhs["+i+"] = "+imageWidhs[i]);
		print("imageHeights["+i+"] = "+imageHeights[i]);
		setBatchMode(false);
	}
}

function getSeriesCompleteness() {//NOT USED
	print("\nnSeries = "+nSeries);
	seriesCompleteness = newArray(nSeries);
	for (i=0; i<seriesFilenamesStr.length; i++) {
		//print("");
		seriesCompleteness[i] = true;
		fnames = seriesFilenamesStr[i];
		fnamesArray = split(fnames, "(,)");
		for (j=0; j<fnamesArray.length; j++) {
			//print("fnamesArray["+j+"] = " + fnamesArray[j]);//juste
			path = dir1 + fnamesArray[j];
			if (!File.exists(path)) {
				seriesCompleteness[i] = false;
				//print("seriesCompleteness["+i+"] = "+seriesCompleteness[i]);
				break;
			}
		}
	}
}

function getImageTypes_MaxWidhs_MaxHeights() {//versus series
	print("\nnSeries = "+nSeries);
	imageTypes = newArray(nSeries);
	maxImageWidhs = newArray(nSeries);
	maxImageHeights = newArray(nSeries);
	maxImageDepths = newArray(nSeries);//INUTILISE POUR LE MOMENT
	for (i=0; i<seriesFilenamesStr.length; i++) {
		//print("");
		fnames = seriesFilenamesStr[i];
		fnamesArray = split(fnames, "(,)");
		maxW = 0; maxH = 0;
		setBatchMode(true);
		bitdepth = 16;
		seriesName = seriesNames[i];
		currentWaveNum = 0;
		checkedTimePoints = 0;
		for (j=0; j<fnamesArray.length; j++) {
			fname = fnamesArray[j];
			//print("fnamesArray["+j+"] = "+fnamesArray[j]);
			extensionlessName = substring(fname, 0, lastIndexOf(fname, "."));
			str = substring(extensionlessName,
				lengthOf(seriesName), lengthOf(extensionlessName));
			//print("str = "+str);
			if (!startsWith(str, "_w")) {//single wavelength
				path = dir1 + fname;
				print("fname = "+fname);
				if (!File.exists(path)) continue;
				open(path, 1);
				bitdepth = bitDepth();
				maxW = getWidth();
				maxH = getHeight();
				close();
				break;
			}
			waveNumStr = substring(str, 2, 3);
			waveNum = parseInt(waveNumStr);
			//print("currentWaveNum = "+currentWaveNum);
			//print("waveNum = "+waveNum);
			if (waveNum==currentWaveNum) continue;
			currentWaveNum = waveNum;
			path = dir1 + fname;
			//print("fname = "+fname);
			if (!File.exists(path)) continue;
			open(path, 1);
			bitdepth = bitDepth();
			width = getWidth();
			if (width>maxW) maxW = width;
			height = getHeight();
			if (height>maxH) maxH = height;
			close();
			if (noChannelDependentBinning) break;
		}
		if (bitdepth==8) imageTypes[i] = "8-bit";
		else if (bitdepth==16) imageTypes[i] = "16-bit";
		else if (bitdepth==24) imageTypes[i] = "RGB";
		print("maxW = "+maxW+"    maxH = "+maxH);
		maxImageWidhs[i] = maxW;
		maxImageHeights[i] = maxH;
		print("maxImageWidhs["+i+"] = "+maxImageWidhs[i]);
		print("maxImageHeights["+i+"] = "+maxImageHeights[i]);
		setBatchMode(false);
	}
}

function getSeriesCalibrationOptions() {//not used
	Dialog.create(macroName);
	s = "";
	for (i=0; i<seriesNames.length; i++) {
		s = s + seriesNames[i] + "\n";
	}
	Dialog.addMessage("Found following series in folder:\n"+s);
	Dialog.addChoice("Calibration option", calibrationOptions)
	Dialog.show();
	calibrationOption = Dialog.getChoice();
}

function fileFilterAndCalibrationParamsDialog() {
	Dialog.create(macroName);
	Dialog.addString("Process Filenames containing", fileFilter);
	Dialog.addString("Exclude Filenames containing", excludingFilter);
	Dialog.addCheckbox("No series have channel-dependent binning",
			noChannelDependentBinning);
	Dialog.addCheckbox("Display series choice dialog", letMeChooseSeries);
	Dialog.addMessage("If no length calibration found,"+
			" use this for all series:");
	Dialog.addNumber("Pixel size", 1);
	Dialog.addNumber("Z step", 0);
	Dialog.addChoice("Unit of length", XYZUnitChoices, XYZUnitChoices[0]);
	
//	if (atLeastOneTimeSeries) {
		//Dialog.addMessage("Time series:");
		Dialog.addMessage("If no time calibration found,"+
				" use this for all series:");
		Dialog.addNumber("Frame interval", 0);
		Dialog.addChoice("Time unit", TUnitChoices, TUnitChoices[1]);
//		Dialog.addCheckbox("Create subfolders to workaround Imaris bug",
//				createFolderForEachOutputSeries);
		Dialog.addCheckbox("Create an output file for each time point",
				oneOutputFilePerTimePoint);
		Dialog.addCheckbox("Timelapse: ignore single timepoint channels",
				ignoreSingleTimepointChannels);
//	}
	Dialog.addCheckbox("Set 'Do z-projections' as default for all series",
				doZprojsByDefault);
	Dialog.addMessage(author);

	Dialog.show();

	fileFilter = Dialog.getString();
	excludingFilter = Dialog.getString();
	noChannelDependentBinning = Dialog.getCheckbox();
	letMeChooseSeries = Dialog.getCheckbox();
	userPixelSize = Dialog.getNumber();
	userVoxelDepth = Dialog.getNumber();
	userLengthUnit = Dialog.getChoice();
//	if (atLeastOneTimeSeries) {
		userFrameInterval = Dialog.getNumber();
		userTUnit = Dialog.getChoice();
		//createFolderForEachOutputSeries = Dialog.getCheckbox();
		oneOutputFilePerTimePoint = Dialog.getCheckbox();
		ignoreSingleTimepointChannels = Dialog.getCheckbox();
//	}
	doZprojsByDefault = Dialog.getCheckbox();
	print("userFrameInterval = "+userFrameInterval);
	print("userTUnit = "+userTUnit);
	/*
	print("createFolderForEachOutputSeries = "+createFolderForEachOutputSeries);
	*/
	print("oneOutputFilePerTimePoint = "+oneOutputFilePerTimePoint);
	print("ignoreSingleTimepointChannels = "+ignoreSingleTimepointChannels);
}

function assignChannelGroupToSeries() {
	seriesChannelGroups = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		for (j=0; j<seriesWithSameChannels.length; j++) {
			//print("seriesWithSameChannels["+j+"] = "+
			//		seriesWithSameChannels[j]);
			if (indexOf(seriesWithSameChannels[j], seriesNames[i])>=0) {
				seriesChannelGroups[i] = j;
				break;
			}
		}
	}
}

/**
  * Display may be incomplete if many channel groups with many channels
 */
function channelGroupsHandlingDialog() {
	doChannelsFromSequences = newArray(seriesWithSameChannels.length);
	doZprojForChannelSequences = newArray(seriesWithSameChannels.length);
	projTypesForChannelSequences = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName+"  -  Channel handling");
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	seriesnames = toArray(seriesWithSameChannels[i], ",");
		if (i>0) Dialog.addMessage("");
		Dialog.addChoice("Channel group "+i+"", seriesnames);

	 	Dialog.addToSameRow();//marche pas apres addCheckboxGroup
	 	Dialog.addCheckbox("Do Z-projections", doZprojsByDefault);

	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	defaults = newArray(chns.length);
	 	for (j=0; j<chns.length; j++) defaults[j] = true;
	 	Dialog.addCheckboxGroup(1, chns.length, chns, defaults);
	 	makeColorsDifferent = false;
	 	chnColors = getChannelColors(chns, makeColorsDifferent);
		channelsSeqProjTypes = initProjTypes(chns, chnColors);
		for (j=0; j<chns.length; j++) {
			Dialog.addChoice(chns[j], projectionTypes, channelsSeqProjTypes[j]);
		}
	}
	Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	doChnStr = "";
	 	doZprojForChannelSequences[i] = Dialog.getCheckbox();
	 	for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getCheckbox();
	 		doChnStr = doChnStr + str + ",";
	 	}
	 	doChnStr = substring(doChnStr, 0, lengthOf(doChnStr)-1);
	 	doChannelsFromSequences[i] = doChnStr;
	 	projTypesStr = "";
		for (j=0; j<chns.length; j++) {
			projTypesStr = projTypesStr + Dialog.getChoice() + ",";
		}
		projTypesStr = substring(projTypesStr, 0, lengthOf(projTypesStr)-1);
		projTypesForChannelSequences[i] = projTypesStr;
	}
	for (i=0; i<doChannelsFromSequences.length; i++) {//verification
		//print("\nSeries: "+seriesnames[i]);//plante ds certains cas
		print("doChannelsFromSequences["+i+"] = "+doChannelsFromSequences[i]);
		print("doZprojForChannelSequences["+i+"] = "+
				doZprojForChannelSequences[i]);
		print("projTypesForChannelSequences["+i+"] = "+
				projTypesForChannelSequences[i]);
	}
}

/**
 * Display may be incomplete if many channel groups with many channels
 */
function channelColorsAndSaturationsDialog() {
	channelSequencesColors = newArray(seriesWithSameChannels.length);
	channelSequencesSaturations = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName+"  -  Channel colors and saturations");
	//channelSequences;
	//seriesWithSameChannels;
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	if (i>0) Dialog.addMessage("");
	 	seriesnames = toArray(seriesWithSameChannels[i], ",");
		Dialog.addChoice("Channel group "+i+"", seriesnames);

	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
		channelColorIndexes = initChannelColorIndexes(chns);
		for (j=0; j<chns.length; j++) {
			Dialog.addChoice(chns[j], compositeColors,
				compositeColors[channelColorIndexes[j]]);
			//channelColorIndexes a refaire pour channelSequences
			Dialog.addToSameRow() ;
			Dialog.addNumber("", 0.01, 2, 5, "% saturated pixels");
		}
	}
	Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	clrs = "";
		saturations = "";
		for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getChoice();
	 		clrs = clrs + str + ",";
	 		saturations = saturations + Dialog.getNumber() + ",";
	 	}
	 	clrs = substring(clrs, 0, lengthOf(clrs)-1);
	 	channelSequencesColors[i] = clrs;
		saturations = substring(saturations, 0, lengthOf(saturations)-1);
		channelSequencesSaturations[i] = saturations;
	}
	for (i=0; i<doChannelsFromSequences.length; i++) {//verification
		seriesnames = toArray(seriesWithSameChannels[i], ",");
		print("\nSeries :"+seriesNames[i]+":");
		print("channelSequencesColors["+i+"] = "+channelSequencesColors[i]);
		print("channelSequencesSaturations["+i+"] = "+
				channelSequencesSaturations[i]);
	}
}

/**
 * Display may be incomplete if more than 4 channel groups
 */
function channelGroupsHandlingDialog_OLD() {
	doChannelsFromSequences = newArray(seriesWithSameChannels.length);
	doZprojForChannelSequences = newArray(seriesWithSameChannels.length);
	projTypesForChannelSequences = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName);
	Dialog.addMessage("Channel handling:");
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	seriesnames = toArray(seriesWithSameChannels[i], ",");
	 	for (j=0; j<seriesnames.length; j++) {
	 		//Dialog.addMessage(seriesnames[j]);//prend trop de place
	 	}
		if (i>0) Dialog.addMessage("");//pour creer un espace
/*
	 	len = lengthOf(seriesWithSameChannels[i]);
	 	maxDisplayableLength = (screenWidth()-100)/6;//1 char ~ 6 pixels
	 	trunkatedSeriesnames = seriesWithSameChannels[i];
	 	if (len > maxDisplayableLength) {
	 		trunkatedSeriesnames = substring(seriesWithSameChannels[i],
	 				0, maxDisplayableLength - 10);//-10 pour ajouter " ..."
	 		trunkatedSeriesnames = trunkatedSeriesnames + " ...";
	 	}
	 	msg = "\nSeries:\n"+trunkatedSeriesnames;
	 	if (i>0)
	 		msg = "\n "+msg;
	 	Dialog.addMessage(msg);
*/
		//remplace bloc desactive supra
		Dialog.addChoice("Channel group "+i+"", seriesnames);

	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	defaults = newArray(chns.length);
	 	for (j=0; j<chns.length; j++) defaults[j] = true;
	 	Dialog.addCheckboxGroup(1, chns.length, chns, defaults);
	 	//Dialog.addCheckboxGroup(rows, columns, labels, defaults);
	 	for (j=0; j<chns.length; j++) defaults[j] = true;
	 	//Dialog.addCheckbox("Do Z-projections", true);//old
	 	Dialog.addCheckbox("Do Z-projections", doZprojsByDefault);
	 	makeColorsDifferent = false;
	 	chnColors = getChannelColors(chns, makeColorsDifferent);
		channelsSeqProjTypes = initProjTypes(chns, chnColors);
		for (j=0; j<chns.length; j++) {
			Dialog.addChoice(chns[j], projectionTypes, channelsSeqProjTypes[j]);
		}
	}
	Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	doChnStr = "";
	 	for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getCheckbox();
	 		doChnStr = doChnStr + str + ",";
	 	}
	 	doChnStr = substring(doChnStr, 0, lengthOf(doChnStr)-1);
	 	doChannelsFromSequences[i] = doChnStr;
	 	doZprojForChannelSequences[i] = Dialog.getCheckbox();
	 	projTypesStr = "";
		for (j=0; j<chns.length; j++) {
			projTypesStr = projTypesStr + Dialog.getChoice() + ",";
		}
		projTypesStr = substring(projTypesStr, 0, lengthOf(projTypesStr)-1);
		projTypesForChannelSequences[i] = projTypesStr;
	}
	for (i=0; i<doChannelsFromSequences.length; i++) {//verification
		//print("\nSeries: "+seriesnames[i]);//plante ds certains cas
		print("doChannelsFromSequences["+i+"] = "+doChannelsFromSequences[i]);
		print("doZprojForChannelSequences["+i+"] = "+
				doZprojForChannelSequences[i]);
		print("projTypesForChannelSequences["+i+"] = "+
				projTypesForChannelSequences[i]);
	}
}

/**
 * Display may be incomplete if more than 4 channel groups
 */
function channelColorsAndSaturationsDialog_OLD() {
	channelSequencesColors = newArray(seriesWithSameChannels.length);
	channelSequencesSaturations = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName);
	//channelSequences;
	//seriesWithSameChannels;
	Dialog.addMessage("Choose channel colors and saturations:");
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	if (i>0) Dialog.addMessage("");
	 	seriesnames = toArray(seriesWithSameChannels[i], ",");
/*
	 	len = lengthOf(seriesWithSameChannels[i]);
	 	maxDisplayableLength = (screenWidth()-100)/6;//1 char ~ 6 pixels
	 	trunkatedSeriesnames = seriesWithSameChannels[i];
	 	if (len > maxDisplayableLength) {
	 		trunkatedSeriesnames = substring(seriesWithSameChannels[i],
	 				0, maxDisplayableLength - 10);//-10 pour ajouter " ..."
	 		trunkatedSeriesnames = trunkatedSeriesnames + " ...";
	 	}
	 	msg = "Series:\n"+trunkatedSeriesnames;
	 	Dialog.addMessage(msg);
*/
		//remplace bloc desactive supra
		Dialog.addChoice("Channel group "+i+"", seriesnames);

	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
		channelColorIndexes = initChannelColorIndexes(chns);
		for (j=0; j<chns.length; j++) {
			Dialog.addChoice(chns[j], compositeColors,
				compositeColors[channelColorIndexes[j]]);
			//channelColorIndexes a refaire pour channelSequences
		}
		for (j=0; j<chns.length; j++) {//defaut sat = 0.01 pour ts les canaux
			Dialog.addNumber(chns[j], 0.01, 2, 5, "% saturated pixels");
		}
/*
		//trop complique
		Dialog.addNumber(chns[j], channelSaturations[j],
				2, 5, "% saturated pixels");
		}
*/
	}
	Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, ",");
	 	clrs = "";
	 	for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getChoice();
	 		clrs = clrs + str + ",";
	 	}
	 	clrs = substring(clrs, 0, lengthOf(clrs)-1);
	 	channelSequencesColors[i] = clrs;
	 	saturations = "";
		for (j=0; j<chns.length; j++) {
			saturations = saturations + Dialog.getNumber() + ",";
		}
		saturations = substring(saturations, 0, lengthOf(saturations)-1);
		channelSequencesSaturations[i] = saturations;
	}
	for (i=0; i<doChannelsFromSequences.length; i++) {//verification
		seriesnames = toArray(seriesWithSameChannels[i], ",");
		print("\nSeries :"+seriesNames[i]+":");
		print("channelSequencesColors["+i+"] = "+channelSequencesColors[i]);
		print("channelSequencesSaturations["+i+"] = "+
				channelSequencesSaturations[i]);
	}
}

function initChannelSaturations(channelSeqs) {//Not used (too complicated)
	channelSeqsSaturations = newArray(seriesWithSameChannels.length);
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	channelSeq = channelSeqs[i];
	 	chns = toArray(channelSeq, ",");
	 	str = "";
	 	for (j=0; j<chns.length; j++) {
	 		str = str + 0.01 + ",";
	 	}
	 	str = substring(str, 0, lengthOf(str)-2);
	 	channelSeqsSaturations[i] = str;
	}
	return channelSeqsSaturations;
}

//Windows forbidden chars in filenames : \ / : * ? " < > |
/** Caracteres speciaux regex autorises dans les noms de fichiers Windows.
    "s" remplace les espaces par \s et conserve les caracteres literaux 's' */
var regexMetachars = newArray("^", "$", "+", "{", "}", "[", "]", "(", ")", "s");


function escapeRegexMetachars(str) {
	//print("\nescapeRegexMetachars(str) :");
	str2 = str;
	for (i=0; i<regexMetachars.length; i++) {
		str2 = replace(str2, "\\"+regexMetachars[i], "\\\\"+regexMetachars[i]);
	}
	//print("str2 = "+str2);
	return str2;
}

/**
 * Requires folder has been analyzed, series built etc.
 * position exists does not mean it's complete, some files may be missing.*/
function findPositionsSeriesBySeries(filenames) {
	//les series ayant une seule position sont marquees par "" 
	//dans positionsSeriesBySeries et userPositionsSeriesBySeries.
	//les positions inexistantes ou non retenues sont marquees par 0
	arraysLength = 0;//at least equal to maxPosition
	nSeries = seriesNames.length;
	//print("findPositionsSeriesBySeries(filenames): nSeries = "+nSeries);
	for (i=0; i<nSeries; i++) {
		n = positionNumbers[i];
		arraysLength += n;
	}
/*
	print("\nfindPositionsSeriesBySeries(filenames):"+
			" total position number: n = "+arraysLength);
*/
	//print("\nmaxPosition = "+maxPosition);
	positionsSeriesBySeries = newArray(arraysLength);
	positionExists = newArray(arraysLength);
	isCompletePosition = newArray(arraysLength);
	userPositionsSeriesBySeries = newArray(arraysLength);
	for (i=0; i<n; i++) {
		positionsSeriesBySeries[i] = 0;
		positionExists[i] = true;
		isCompletePosition[i] = true;
		userPositionsSeriesBySeries[i] = 0;
	}
	index = -1;
	for (k=0; k<nSeries; k++) {
		fnames = split(seriesFilenamesStr[k], ",");
		print("seriesNames["+k+"] = "+seriesNames[k]+" :");
		seriesName = seriesNames[k];
		seriesName = escapeRegexMetachars(seriesName);
	//	print("seriesName = "+seriesName);
		npositions = positionNumbers[k];
		mp = isMultiPosition(filenames, seriesNames[k]);
		mw = isMultiChannel(filenames, seriesNames[k]);
		waveRegex = ".*";
		if (mw) waveRegex = "_w\\d.*";
		if (mp) {
			for (i=0; i<npositions; i++) {
				iPlus1 = i+1;
				pExists = false;
				for (j=0; j<fnames.length; j++) {
					seriesNameLessName = substring(fnames[j],
					lengthOf(seriesNames[k]), lengthOf(fnames[j]));
					//print("seriesNameLessName = "+seriesNameLessName);//ok
					//print("fnames["+j+"] = "+fnames[j]);
					fname = fnames[j];
					fname = escapeRegexMetachars(fname);
					str = "_s"+iPlus1;
					//print("str = "+str);
			//		if (matches(seriesNameLessName,
			//				waveRegex+"_s"+iPlus1+".*")) {//FONCTIONNE
					if (matches(fnames[j],
							seriesName+waveRegex+"_s"+iPlus1+".*")) {//FCTIONNE
						pExists = true;
						positionsSeriesBySeries[++index] = "_s"+iPlus1;
						positionExists[index] = true;
						break;
					}
				}
				//print("findPositionsSeriesBySeries(filenames):"+
				//	"\npExists = "+pExists);
				if (!pExists) index++;
			}
		}
		else {
			positionsSeriesBySeries[++index] = "";
			positionExists[index] = true;
		}
	}
	for (i=0; i<positionsSeriesBySeries.length; i++) {
		print("positionsSeriesBySeries["+i+"] = "+
				positionsSeriesBySeries[i]);
	}
	//calcul de isCompletePosition et 
	//initialisation de userPositionsSeriesBySeries:
	//refaire une boucle a trois indices analogue a la precedente:
	//pour chaque serie, calculer le nb de fichiers attendus pour 
	//chaque position;
	//verifier que tous les fichiers attendus sont presents dans la liste;
	//s'il n'en manque aucun, isCompletePosition[index] = true;
	index = -1;
	for (k=0; k<nSeries; k++) {//EN COURS
		//faux si certains canaux n'ont que 1er et dernier frame 
		//nPositions = getPositionsNumber(filenames, seriesNames[k]);
		nPositions = positionNumbers[k];
		mp = isMultiPosition(filenames, seriesNames[k]);
		ts = isTimeSeries(filenames, seriesNames[k]);
		nFrames = getFramesNumber(filenames, seriesNames[k]);
		sc = isSingleChannel(filenames, seriesNames[k]);
		mc = isMultiChannel(filenames, seriesNames[k]);
		//print("ICI");
		channels = getChannelNames(filenames, seriesNames[k]);
		if (sc)
			nChn = 1;
		else if (mc)
			nChn = channels.length;
		expectedFileNumber = nFrames * nChn;
		extensionRegex = "TIF|tif|TIFF|tiff|STK|stk";
		index = -1;
		if (mp) {
			//print("npositions = "+npositions);
			for (i=0; i<npositions; i++) {
				if (!positionExists[i]) {
					index++;
					continue;
				}
				fileNumber = 0;
				iPlus1 = i+1;
				filenameRegex = seriesNames[k];
				if (mc) filenameRegex = filenameRegex+"_w\\d";
				filenameRegex = filenameRegex+"_s"+iPlus1;
				if (ts) filenameRegex = filenameRegex+"_t\\d*";
				filenameRegex = filenameRegex+"\\."+extensionRegex;
				for (j=0; j<fnames.length; j++) {
					if (matches(fnames[j], filenameRegex)) {
						fileNumber++;
					}
				}
				if (fileNumber==expectedFileNumber) {
					isCompletePosition[++index] = true;
					userPositionsSeriesBySeries[index] = "_s"+iPlus1;
				}
			}
		}
		else {
			fileNumber = 0;
			filenameRegex = seriesNames[k];
			if (mc) filenameRegex = filenameRegex+"_w\\d";
			if (ts) filenameRegex = filenameRegex+"_t\\d*";
			filenameRegex = filenameRegex+"\\."+extensionRegex;
			for (j=0; j<fnames.length; j++) {
				if (matches(fnames[j], filenameRegex)) {
					fileNumber++;
				}
			}
			if (fileNumber==expectedFileNumber) {
				isCompletePosition[++index] = true;
				userPositionsSeriesBySeries[index] = "";
			}
		}
	}
	for (i=0; i<positionsSeriesBySeries.length; i++) {
		userPositionsSeriesBySeries[i] = positionsSeriesBySeries[i];
	}
	//print("\nEnd of findPositionsSeriesBySeries(filenames):");
	for (i=0; i<positionsSeriesBySeries.length; i++) {
		print("positionsSeriesBySeries["+i+"] = "+
				positionsSeriesBySeries[i]);
	}
}

//Pb : les positions desactivees ne st pas les bonnes (semble resolu)
//AFFICHE LES POSITIONS SUR DES LIGNES HORIZONTALES DANS PLUSIEURS DIALOGUES
//SI NECESSAIRE POUR EVITER QUE LEUR HAUTEUR DEPASSE CELLE DE L'ECRAN
function positionsSeriesBySeriesDialog(filenames) {
	print("");
	print("positionsSeriesBySeriesDialog: seriesNames.length = "
			+seriesNames.length);
	multipositionSeries = 0;
	for (k=0; k<seriesNames.length; k++) {
		n = positionNumbers[k];
		//print("seriesNames["+k+"] = "+seriesNames[k]);
		if (doSeries[k] && n>1) {
			multipositionSeries++;
		}
	}
	print("multipositionSeries = "+multipositionSeries);
	if (multipositionSeries==0) return;
	//3 series / h = 198 --o-> 1 serie pour h = 66;
	//soustraire 140 pour la fenetre, le message et le bouton OK
	nWindows = 1+floor(multipositionSeries * 66 / (screenHeight() - 140));
	//nWindows = floor(multipositionSeries * 66 / (screenHeight() - 940));
	//nWindows = floor(multipositionSeries * 66 / (screenHeight() - 900));
	if (nWindows==0) nWindows = 1;
	seriesPerWindow = floor(multipositionSeries / nWindows);
	seriesInLastWindow = multipositionSeries % nWindows;
	if (seriesInLastWindow==0) seriesInLastWindow = seriesPerWindow;
	print("nWindows = "+nWindows);
	print("seriesPerWindow = "+seriesPerWindow);
	print("seriesInLastWindow = "+seriesInLastWindow);
	//Create dialogs
	index = 0;
	seriesIndex = 0;
	for (k=0; k<seriesNames.length; k++) {
		if (doSeries[k] && positionNumbers[k]>1) break;
		if (!doSeries[k] || positionNumbers[k]<2) {
		//if (!doSeries[k] || positionNumbers[k]<2) {
			seriesIndex++;
			index += positionNumbers[k];
		}
	}
	index0 = index;
	//index0 = numero 1ere position de positionsSeriesBySeries a traiter
	print("index0 = "+index0);
	//seriesIndex0 = numero 1ere serie a taiter
	seriesIndex0 = seriesIndex;
	print("seriesIndex0 = "+seriesIndex0);
	for (w=0; w<nWindows; w++) {
		Dialog.create(macroName);
		Dialog.addMessage("Choose positions to be processed:");
		lines = 0;//nb de series ajoutees aux dialogues
		k = seriesIndex0;
		while (lines < seriesPerWindow) {
		//for (k=seriesIndex; k<seriesIndex+seriesPerWindow; k++) {
			if (k==seriesNames.length) break;
			n = positionNumbers[k];
	//		print("seriesNames["+k+"] = "+seriesNames[k]);
			//index += n;
			if (doSeries[k] && n>1) {
				lines++;
				Dialog.addMessage(seriesNames[k]+":");
				print("n = "+n);
				n2 = 0;
				//n2 : nb de positions reellement presentes, different de n
				for (i=index; i<index+n; i++) {
					//n2++;
					//print("index = "+index);
					//print("i = "+i);
					//positionOK = positionExists[i] && isCompletePosition[i];
					//positionOK = positionExists[i];//isCompletePosition: pb
					if (i==positionsSeriesBySeries.length) break;
					//if (positionsSeriesBySeries[i]=="0") continue;
					if (positionsSeriesBySeries[i]==0) continue;
					n2++;
				}
				//print("n2 = "+n2);
				//columns = n % 24;
				//rows = n / 24 + 1;
				//les rangees CheckboxGroup doivent etre completes => 
				//il faut mettre ts les Checkbox sur une seule ligne
				rows = 1;
				columns = n2;
				start = index;
				end = index + n;
				labels = newArray(n2);
				p = 0;
				for (i=index; i<index+n; i++) {
					if (i==positionsSeriesBySeries.length) break;
					//if (positionsSeriesBySeries[i]=="0") continue;
					if (positionsSeriesBySeries[i]==0) continue;
					labels[p] = positionsSeriesBySeries[i];
					p++;
				}
				defaults = newArray(n2);
				Array.fill(defaults, true);
				Dialog.addCheckboxGroup(rows, columns, labels, defaults);
			}
			index += n;
			k++;
		}
		Dialog.show();

		for (i=0; i<positionsSeriesBySeries.length; i++) {
			userPositionsSeriesBySeries[i] = positionsSeriesBySeries[i];
		}
		//Answer dialog
		index = index0;
		seriesIndex = seriesIndex0;
		lines = 0;
		k = seriesIndex0;
	//	print("seriesIndex0 = "+seriesIndex0);
		while (lines < seriesPerWindow) {
		//for (k=seriesIndex; k<seriesIndex+seriesPerWindow; k++) {
			//print("seriesNames["+k+"] = "+seriesNames[k]);
	//		print("k = "+k);
	//		print("index = "+index);
			if (k==seriesNames.length) break;
			n = positionNumbers[k];
			//index += n;
			if (doSeries[k] && n>1) {
				lines++;
	//			print("answer dialog : i = "+i);
				for (i=index; i<index+n; i++) {
					if (i==positionsSeriesBySeries.length) break;
					//positionOK = positionExists[i] && isCompletePosition[i];
					positionOK = positionExists[i];//isCompletePosition: problem
					if (positionOK) {
						if (!doSeries[k]) {
							userPositionsSeriesBySeries[i] = false;
						}
						else {
							if (positionsSeriesBySeries[i]==0) continue;
							if (Dialog.getCheckbox())
								userPositionsSeriesBySeries[i] =
									positionsSeriesBySeries[i];
							else
								userPositionsSeriesBySeries[i] = 0;
						}
					}
				}
			}
			index += n;
			k++;
		}
		seriesIndex += seriesPerWindow;
		//seriesIndex += seriesPerWindow + n;
	}
//	print("Answer dialog: ");
	for (i=0; i<userPositionsSeriesBySeries.length; i++) {
		print("userPositionsSeriesBySeries["+i+"] = "
				+userPositionsSeriesBySeries[i]);
	}
}

function printParams() {
	print("");
	//print(macroName+" Parameters:");
	print("Parameters:");
	print("Input dir: "+dir1);
	print("Ouput dir: "+dir2);
	print("fileFilter = "+"\""+fileFilter+"\"");

	print("userPixelSize = "+userPixelSize);
	print("userVoxelDepth = "+userVoxelDepth);
	print("userLengthUnit = "+userLengthUnit);
	print("userFrameInterval = "+userFrameInterval);
	print("userTUnit = "+userTUnit);

	print("firstSlice = "+firstSlice);
	print("lastSlice = "+lastSlice);

	print("createFolderForEachOutputSeries = "+createFolderForEachOutputSeries);
	print("oneOutputFilePerTimePoint = "+oneOutputFilePerTimePoint);
	print("End of Parameters");
}

function foundAtLeastOneTimeSeries() {
	for (i=0; i<seriesNames.length; i++)
		if (isTimeSeries(list, seriesNames[i])) return true;
	return false;
}

function getDirs() {
	dir1 = getDirectory("Choose Source Directory ");
	dir2 = getDirectory("Choose Destination Directory ");
	while (dir2==dir1) {
		showMessage("Destination folder must be different from source");
		dir2 = getDirectory("Choose Destination Directory ");
	}
}

function getFiles(dir) {
	list = getFileList(dir);
	if (list.length==0) {
		showMessage(macroName,"Input folder:\n"+dir+"\nseems empty");
		exit();
	}
	j=0;
	list2 = newArray(list.length);
	for (i=0; i<list.length; i++) {
		s = list[i];
		if (File.isDirectory(dir+s)) continue;
		list2[j] = s;
		j++;
	}
	if (j<1) {
		showMessage(macroName,"Input folder:\n"+dir+
			"\nseems empty or to contain only subfolders");
		exit();
	}
	for (i=0; i<list2.length; i++) {
		list2[i] = toString(list2[i]);
	}
	list2 = Array.trim(list2, j);
	list2 = Array.sort(list2);
	return list2;
}

/** returns TIFF and STK files contained in list not matching excludingFilter
    and matching fileFilter */
function filterList(list, fileFilter, excludingFilter) {
	list2 = newArray(list.length);
	j=0;
	for (i=0; i<list.length; i++) {
		s = list[i];
		if (fileFilter!="" && indexOf(s, fileFilter)<0) continue;
		if (excludingFilter!="" && indexOf(s, excludingFilter)>=0) continue;
		s2 = toLowerCase(s);
		ext = getExtension(s);
		if (!endsWith(s2, ".tif") && !endsWith(s2, ".stk")) continue;
		list2[j] = s;
		j++;
	}
	if (j<1) {
		showMessage(macroName,
				"Input folder seems not to contain TIFF or STK files "+
				"matching "+fileFilter);
		exit();
	}
	for (i=0; i<list2.length; i++) {
		list2[i] = toString(list2[i]);
	}
	list2 = Array.trim(list2, j);
	list2 = Array.sort(list2);
	return list2;
}

//a appeler apres choix des series;
//il faut ensuite restreindre doSeries et seriesNames aux elements selectionnes
function reduceListToSelectedSeries(list) {
//function reduceListToSelectedSeries(list, seriesNames, doSeries) {
//si seriesNames et doSeries en arguments, ne peuvent etre modifies par la 
//fonction (transmission par reference)
	doAll = true;
	keptSeries = 0;
	for (i=0; i<doSeries.length; i++) {
		if (doSeries[i]) {
			keptSeries++;
		}
		else {
			doAll = false;
		}
	}
	if (keptSeries==0) {
		msg = "No series selected; exiting macro";
		print(msg);
		showMessage(msg);
		exit();
	}
	if (doAll) return list;
	doSeriesFiltered = newArray(keptSeries);
	seriesNamesFiltered = newArray(keptSeries);
	j = 0;
	for (i=0; i<doSeries.length; i++) {
		if (doSeries[i]) {
			doSeriesFiltered[j] = true;
			seriesNamesFiltered[j++] = seriesNames[i];
		}
	}
	list2 = newArray(list.length);
	k = 0;
	for (i=0; i<keptSeries; i++) {
		for (j=0; j<list.length; j++) {
			if (!startsWith(list[j], seriesNamesFiltered[i])) continue;
			list2[k++] = list[j];
		}
	}
	list2 = Array.trim(list2, k);
	doSeries = Array.copy(doSeriesFiltered);
	seriesNames = Array.copy(seriesNamesFiltered);
	return list2;
}

function initXYCalibrations(seiesNames) {
	XYCalibrations = newArray(seiesNames.length);
	for (i=0; i<seiesNames.length; i++) {
		XYCalibrations[i] = 1;
	}
	return XYCalibrations;
}

function initZCalibrations(seiesNames) {
	ZCalibrations = newArray(seiesNames.length);
	for (i=0; i<seiesNames.length; i++) {
		ZCalibrations[i] = 0;
	}
	return ZCalibrations;
}

function initXYZUnits(seiesNames) {
	XYZUnits = newArray(seiesNames.length);
	for (i=0; i<seiesNames.length; i++) {
		XYZUnits = XYZUnitChoices[0];//"pixel"
	}
	return XYZUnits;
}

function initTimeIntervals(seiesNames) {
	TimeIntervals = newArray(seiesNames.length);
	for (i=0; i<seiesNames.length; i++) {
		TimeIntervals[i] = 0;
	}
	return TimeIntervals;
}

function initTUnits(seiesNames) {
	TUnits = newArray(seiesNames.length);
	for (i=0; i<seiesNames.length; i++) {
		TUnits[i] = TUnitChoices[1];//"s"
	}
	return TUnits;
}

function colorIndex(colorStr) {
	for (i=0; i<compositeColors.length; i++) {
		if (colorStr==compositeColors[i]) return i;
	}
	return NaN;
}

function initProjTypes(channels, channelColors) {
	projtypes = newArray(channels.length);
	for (i=0; i<channels.length; i++) {
		projtypes[i] = projectionTypes[1];
		if (channelColors[i]=="c4")
			projtypes[i] = projectionTypes[2];
	}
	return projtypes;
}

function finish() {
	print("\n \n"+macroName+" done.\nProcess time: "+
			((getTime()-startTime)/1000)+"s");
	selectWindow("Log");
	saveAs("Text", dir2+"Log.txt");
}

function getSeriesNameDelimiter(filename) {//end of series name
	if (matches(filename, ".*_w\\d{1}.*"))
		return substring(filename, lastIndexOf(filename, "_w"));
	if (matches(filename, ".*_s\\d{1,3}.*"))
		return substring(filename, lastIndexOf(filename, "_s"));
	if (matches(filename, ".*_t\\d{1,5}.*"))
		return substring(filename, lastIndexOf(filename, "_t"));
	return substring(filename, lastIndexOf(filename, "."));
}

//marche pas
function getChannelRightDelimiter_NEW(filename) {//end of channel name
	print("filename = "+filename);
	channelSplitString = "(_w\\d{1}.*)";
	splittenName = split(filename, channelSplitString);
	for (i = 0; i < splittenName.length; i++) {
		print("splittenName["+i+"] = "+splittenName[i]);
	}
	print("splittenName.length = "+splittenName.length);
	after_w = splittenName[splittenName.length-1];
	print("after_w = "+after_w);
	if (matches(after_w, ".*_s\\d{1,3}.*"))
		return substring(after_w, lastIndexOf(after_w, "_s"));
	if (matches(after_w, ".*_t\\d{1,5}.*"))
		return substring(after_w, lastIndexOf(after_w, "_t"));
	return substring(after_w, lastIndexOf(after_w, "\\."));
}

//ne marche pas si _t\d.* ou _s\d.* avant channel suffix _w\d
//l'argument doit etre filename ampute de seriesName
function getChannelRightDelimiter(str) {//returns string after channel name
	//print("getChannelRightDelimiter(str) : str = "+str);
	if (matches(str, ".*_s\\d{1,3}.*"))
		return substring(str, lastIndexOf(str, "_s"));
	if (matches(str, ".*_t\\d{1,5}.*"))
		return substring(str, lastIndexOf(str, "_t"));
	return substring(str, lastIndexOf(str, "."));
}

/** Finds series names in filenames array */
function getSeriesNames(filenames) {
	nFiles = filenames.length;
	print("\nnFiles = "+nFiles);
	tmp = newArray(nFiles);
	//print("\nFile names\n ");
	for (i=0; i<nFiles; i++) {
		name = filenames[i];
		//print("filename: "+name);
		delim = getSeriesNameDelimiter(name);
		//print("delim = "+delim);
		splittenName = split(name, "("+delim+")");
		tmp[i] = splittenName[0];
	}
//	print("\ntmp:");
//	for (i=0; i<tmp.length; i++) print(tmp[i]);
	names = newArray(nFiles);
	alreadyAdded = newArray(tmp.length);
	names[0] = tmp[0];
	alreadyAdded[0] = tmp[0];
	j=0;
	for (i=1; i<tmp.length; i++) {
		if (tmp[i]==tmp[i-1]) continue;
		j++;
		if (tmp[j] != alreadyAdded[j]) {
			names[j] = tmp[i];
			alreadyAdded[j] = tmp[j];
		}
	}
	nSeries = j+1;
	//print("nSeries = "+j+1);
	names = Array.trim(names, nSeries);
	print("\nrawSeriesNames:");
	for (i=0; i<names.length; i++) print(names[i]);
	nSeries = names.length;
	for (i=0; i<names.length; i++) {
		for (j=i+1; j<names.length; j++) {
			if (names[j]==names[i]) {
				names[j] = "";
				nSeries--;
			}
		}
	}
	filteredSeriesNames = newArray(nSeries);
	j=0;
	for (i=0; i<names.length; i++) {
		if (names[i]=="") continue;
		filteredSeriesNames[j] = names[i];
		j++;
	}
	print("\nSeriesNames from filenames-filtered filenames:");
	for (i=0; i<filteredSeriesNames.length; i++) print(filteredSeriesNames[i]);
	return filteredSeriesNames;
}

/**
 * Renvoie un tableau de dimension nSeries dont les elements sont les filenames 
 * separes par des virgules
 */
function getSeriesFilenames(filenames) {
	//print("\ngetSeriesFilenames(filenames) :");
	//seriesNames = getSeriesNames(filenames);//normalement deja fait avant
	filenamesArray = newArray(nSeries);
	n = 0;
	for (j=0; j<seriesNames.length; j++) {
		seriesName = seriesNames[j];
	//	print("seriesName = "+seriesName);
		filenamesStr = "";
		for (i=0; i<filenames.length; i++) {
		//	print("filenames["+i+"] = "+filenames[i]);
			index = indexOf(filenames[i],seriesNames[j]);
			if (index<0) continue;
			//endOfName = substring(filenames[i],index+lengthOf(seriesName));
			endOfName = substring(filenames[i], lengthOf(seriesName));
		//	print ("endOfName = "+endOfName);
			ext = getExtension(endOfName);
			//if (!startsWith(endOfName, ext) && !startsWith(endOfName, "_t")
			endOfName = substring(endOfName, 0, lastIndexOf(endOfName, ext));
			contains_w = false;
			wSplit = split(endOfName, "(_w\\d{1})");
//			if (wSplit.length > 2) continue;//necessaire
			for (k=0; k<wSplit.length; k++) {
				if (startsWith(wSplit[k], "_w")) contains_w = true;
				//print("wSplit["+k+"] = "+wSplit[k]);
			}
			//print("contains_w = "+contains_w);
	//		if (contains_w) continue;
			contains_s = false;
			sSplit = split(endOfName, "(_s\\d{1,3})");
//			if (sSplit.length > 2) continue;
			for (k=0; k<sSplit.length; k++) {
				if (startsWith(sSplit[k], "_s")) contains_s = true;
				//print("sSplit["+k+"] = "+sSplit[k]);
			}
			//print("contains_s= "+contains_s);
	//		if (contains_s) continue;
			contains_t = false;
			tSplit = split(endOfName, "(_t\\d{1,5})");
//			if (tSplit.length > 2) continue;
			for (k=0; k<tSplit.length; k++) {
				if (startsWith(tSplit[k], "_t")) contains_t = true;
				//print("tSplit["+k+"] = "+tSplit[k]);
			}
			//print("contains_t = "+contains_t);
	//		if (contains_t) continue;
			//getSeriesFileNumbers() : nSeries = 8"+i+"] = "+filenames[i]);
//			if (matches(filenames[i], seriesName+"_"+".*")) {
				filenamesStr = filenamesStr + filenames[i] + ",";
				n++;
//			}
		}
		//print("filenamesStr = "+filenamesStr);//ICI ICI ICI parfois ""
		filenamesStr = substring(filenamesStr, 0, lengthOf(filenamesStr)-1);
		filenamesArray[j] = filenamesStr;
	}
	//print("getSeriesFilenames(filenames) end");
	return filenamesArray;
}

function getSeriesFileNumbers(seriesFilenamesStr) {
	nSeries = seriesFilenamesStr.length;
	//print("getSeriesFileNumbers() : nSeries = "+nSeries);
	seriesFileNumbers = newArray(nSeries);
	separator = ",";
	for (i=0; i<nSeries; i++) {
		a = toArray(seriesFilenamesStr[i], separator);
		//print("\n"+seriesNames[i] + " :");
		for (j=0; j<a.length; j++) {
			//print(a[j]);
		}
		seriesFileNumbers[i] = a.length;
	}
	return seriesFileNumbers;
}

/**
 * Renvoie un tableau de dimension nSeries dont les elements sont les positions 
 * _s1, _s2, _s3 etc separees par des virgules
 */
function getSeriesPositions(filenames) {	
}

/**
 * Renvoie un tableau de dimension nSeries dont les elements sont les temps 
 * d'acquisition _t1, _t2, _t3 etc separes par des virgules
 */
function getSeriesTimePoints(filenames) {	
}

/** returns the array of file extensions of channels used in series */
function getExtensions(filenames, seriesName) {
	nFiles = getFilesNumber(seriesName);
	channels = getChannelNames(filenames, seriesName);
	nChn = channels.length;
	exts = newArray(nChn);
	for (k=0; k<nChn; k++) {
		if (channels[k]==seriesName) channels[k]="";
		j = 0;
		for (i=0; i<filenames.length; i++) {
			name = filenames[i];
			name = seriesNameLessFilename(name, seriesName);
			if (!matches(name, "_"+".*")) continue;
			if (matches(name, channels[k]+".*")) {
				ext = getExtension(name);
				exts[k] = ext;
				break;
			}
			j++;
			if (j==nFiles) break;
		}
	}
	return exts;
}

function isSingleChannel(filenames, seriesName) {//not used
	multipleChannel = isMultiChannel(filenames, seriesName);
	return !multipleChannel;
}

function isMultiChannel(filenames, seriesName) {
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!startsWith(name, "_w")) continue;
		if (matches(name, "_w2.*")) return true;
	}
	return false;
}


/* renvoie seriesWithSameChannels
 * Renvoie un tableau de dimension egale au nb de sequences _w1, _w2, ...,
 * presentes dans dir1 et dont les elements sont les noms des series
 * faites avec une sequence donnee separes par des virgules;
 * pourrait renvoyer les numeros des series (0 a nSeries) a la place */
function groupSeriesHavingSameChannelSequence() {//fonctionne
	nSeq = channelSequences.length;
	a = newArray(nSeq);//number of different sequences
	for (i=0; i<nSeq; i++) {
		a[i] = "";
		for (j=0; j<nSeries; j++) {
			if (seriesChannelSequences[j] == channelSequences[i]) {
				a[i] = a[i] + seriesNames[j] + ",";
			}
		}
		a[i] = substring(a[i], 0, lengthOf(a[i]) - 1);
	}
	for (i=0; i<a.length; i++) {
		print("a["+i+"] = "+a[i]);
	}
	return a;
}

/* Renvoie channelSequences
 * Renvoie un tableau de dimension egale au nb de sequences _w1, _w2, ...,
 * presentes dans dir1 et dont les elements sont les _w1, _w2, ... separes
 * par des virgules (reduction du tableau seriesChannelSequences() renvoye
 * par getSeriesChannelSequences() a ses elements non redondants) */
function getChannelSequences(seriesChannelSequences) {
	n = seriesChannelSequences.length;//n = nSeries
	seqs = newArray(n);
	seqs[0] = seriesChannelSequences[0];
	nSeq = 1;
	for (i=1; i<n; i++) {
		newSeq = true;
		for (j=0; j<=i; j++) {
			if (seriesChannelSequences[i] == seqs[j]) {
				newSeq = false;
				break;
			}
		}
		if (newSeq)
			seqs[nSeq++] = seriesChannelSequences[i];
	}
	print("nSeq = "+nSeq);
	seqs = Array.trim(seqs, nSeq);
	for (i=0; i<nSeq; i++) {
		print("seqs["+i+"] = "+seqs[i]);
	}
	return seqs;
}

/* Renvoie seriesChannelSequences
 * Renvoie un tableau de dimension nSeries dont les elements sont les 
 * channelNames separes par des virgules */
function getSeriesChannelSequences() {//semble fonctionner
	//print("\ngetSeriesChannelSequences():");
	//print("nSeries = "+nSeries);
	seriesChannels = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		//print("");
		//print("seriesFilenamesStr["+i+"] = "+seriesFilenamesStr[i]);//ok
		fnames = split(seriesFilenamesStr[i], "(,)");
		chn = newArray(fnames.length);
		//print("fnames.length = "+fnames.length);
		alreadyAdded = newArray(fnames.length);
		for (j=0; j<fnames.length; j++) {
			chn[j] = "";
			alreadyAdded[j] = "";
		}
		//print("seriesNameLess names");
		k = 0;
		for (j=0; j<fnames.length; j++) {
			seriesNameLessName = substring(fnames[j],
					lengthOf(seriesNames[i]), lengthOf(fnames[j]));
			//print(seriesNameLessName);//ok
			delim = getChannelRightDelimiter(seriesNameLessName);
			//print("getSeriesChannelSequences() :"+
			//	"\nChannelRightDelimiter = delim = "+delim);
			index1 = lastIndexOf(seriesNameLessName, "_w");
			if (index1<0) continue;
			index2 = indexOf(seriesNameLessName, delim);
			str = substring(seriesNameLessName, index1, index2);//ok
			//print("str = "+str);
			addit = true;
			//print("j = "+j);
			//print("k = "+k);
			//print("addit = "+addit);
			if (j==0) {
				//print("chn[k] = str;");
				chn[k] = str;
				alreadyAdded[k] = str;
				k++;
			}
			else {
				for (m=0; m<k; m++) {
					if (str==alreadyAdded[m]) {
						addit = false;
						break;
					}
				}
				if (addit) {			
					chn[k] = str;
					alreadyAdded[k] = str;
					k++;
				}
			}
			if (k==fnames.length) break;
		}
		nchn = 0;
		for (j=0; j<chn.length; j++) {
			if (chn[j]=="") break;
			nchn++;
		}
		chn = Array.trim(chn, nchn);
		seriesChannels[i] = "";
		for (j=0; j<chn.length; j++) {
			//print("chn["+j+"] = "+chn[j]);
			seriesChannels[i] = seriesChannels[i] + chn[j] + ",";
		}
		if (endsWith(seriesChannels[i], ",")) {
			seriesChannels[i] = substring(seriesChannels[i],
					0, lastIndexOf(seriesChannels[i], ","));
		}
	}
	undefinedChannels = 0;
	print("\ngetSeriesChannelSequences():");
	for (i=0; i<nSeries; i++) {
		if (seriesChannels[i] == "") {
			//seriesChannels[i] = "Undefined_Channel_"+undefinedChannels;
			seriesChannels[i] = "Undefined_Channel";
			undefinedChannels++;
		}
		print("seriesChannels["+i+"] = "+seriesChannels[i]);
	}
	return seriesChannels;
}

function seriesNameLessFilename(filename, seriesName) {
//print("seriesNameLessFilename(filename,seriesName): seriesName = "+seriesName);
	index = indexOf(filename, seriesName);
	if (lengthOf(seriesName)<1 || index<0) return filename;
	s = substring(filename, lengthOf(seriesName));
	return s;
}

function getFilesNumber(seriesName) {
	nFiles = 0;
	for (k=0; k<seriesNames.length; k++) {
		if (seriesNames[k]==seriesName) {
			nFiles = seriesFileNumbers[k];
			break;
		}
	}
	return nFiles;
}

//A REVOIR
/** returns array of channel names used in given series */
function getChannelNames(filenames, seriesName) {
	//print("\n"+seriesName);
	nFiles = getFilesNumber(seriesName);
	//print("getChannelNames(filenames, seriesName): nFiles in series = "
	//		+nFiles);
	tmp = newArray(nFiles+1);
	j = 0;
	//print("filenames:");
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		//PEUT-ETRE PB si _w dans seriesNames[k] (probablement pas)
		if (!matches(name, "_w\\d"+".*")) continue;
	//	print("seriesName = "+seriesName);
		//print("seriesNameLessFilename = "+name);
		//print(name);
		//delim = getChannelRightDelimiter(seriesName+name);
		delim = getChannelRightDelimiter(name);
		//print("ChannelRightDelimiter = delim = "+delim);
		index1 = lengthOf(seriesName);
		index2 = indexOf(seriesName+name, delim);
		str = substring(seriesName+name, index1, index2);
		tmp[j] = str;
		j++;
		if (j==nFiles) break;
	}
	alreadyAdded = newArray(tmp.length);
	channels = newArray(tmp.length);
	channels[0] = tmp[0];
	alreadyAdded[0] = tmp[0];
	j=0;
	for (i=1; i<tmp.length; i++) {
		if (tmp[i]==tmp[i-1]) continue;
		j++;
		if (tmp[j]!=alreadyAdded[j]) {
			channels[j] = tmp[i];
			alreadyAdded[j] = tmp[j];
		}
	}
	nChn = j;
	//if (nChn==0) return newArray(seriesName);
	if (nChn==0) return newArray("");
	channels = Array.trim(channels, nChn);
	//print("nChn = "+j);
	//for (i=0; i<channels.length; i++) print(channels[i]);
	return channels;
}

function isMultiPosition(filenames, seriesName) {
	nFiles = filenames.length;
	for (i=0; i<nFiles; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			return true;
		}
	}
	return false;
}

//renvoie parfois une valeur fausse (semble ok depuis 41j)
function getPositionsNumber(filenames, seriesName) {
	//print("getPositionsNumber(filenames, "+seriesName+")");
	mp = isMultiPosition(filenames, seriesName);
	if (!mp) return 1;
	ts = isTimeSeries(filenames, seriesName);
	positionDelimiter = ".";
	if (ts) positionDelimiter = "_t";
	nFiles = getFilesNumber(seriesName);
	print("nFiles in series "+seriesName+" : "+nFiles);
	j = 0;
	nPositions = 1;
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		//print(seriesName);
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			splittenName = split(name, "(_s)");
			str = splittenName[splittenName.length-1];//last element
			posStr = substring(str,0,indexOf(str,positionDelimiter));
			n = parseInt(posStr);
			nPositions = maxOf(nPositions, n);
			j++;
		}
		if (j==nFiles) break;
	}
	return nPositions;
}

function isTimeSeries(filenames, seriesName) {
	nFiles = filenames.length;
	for (i=0; i<nFiles; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (!matches(name, "_"+".*"+"_t"+".*")) continue;
		if (matches(name, ".*_t\\d{1,5}.*")) {
			return true;
		}
	}
	return false;
}

function getFramesNumber(filenames, seriesName) {
	ts = isTimeSeries(filenames, seriesName);
	if (!ts) return 1;
	timeDelimiter = ".";
	nFiles = getFilesNumber(seriesName);
	//print("getFramesNumber(filenames, seriesName) nFiles in series = "+nFiles);
	j = 0;
	nFrames = 0;
	//print("filenames:");
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		//print(name);
		if (matches(name, ".*_t\\d{1,5}.*")) {
			splittenName = split(name, "(_t)");
			str = splittenName[splittenName.length-1];//last element
			//print("str: "+str);
			timeStr = substring(str, 0, indexOf(str, timeDelimiter));
			//print("posStr: "+posStr);
			n = parseInt(timeStr);
			nFrames = maxOf(nFrames, n);
			j++;
		}
		if (j==nFiles) break;
	}
	return nFrames;
}

/* Returns array of frame numbers for each channel 
 * of series corresponding to seriesNameIndex
 * EN COURS */
function getFrameNumbers(filenames, seriesIndex) {
	seriesName = seriesNames[seriesIndex];
	ts = isTimeSeries(filenames, seriesName);
	chnSeq = toArray(seriesChannelSequences[seriesIndex], ",");
	frameNumbers = newArray(chnSeq.length);
	for (k=0; k<chnSeq.length; k++) {
		nframes = 1;
		if (ts) {
			//frameNumbers[i] = 
			//channelSuffix = channels[channelIndex];
			timeDelimiter = ".";
			nFiles = getFilesNumber(seriesName);
//print("getFramesNumbers(filenames, seriesName) nFiles in series = "+nFiles);
			j = 0;
			nframes = 0;
			//print("filenames:");
			for (i=0; i<filenames.length; i++) {
				name = filenames[i];
				name = seriesNameLessFilename(name, seriesName);
				if (!matches(name, "_"+".*")) continue;
				if (!matches(name, chnSeq[k]+".*")) continue;
				//print(name);
				if (matches(name, ".*_t\\d{1,5}.*")) {
					splittenName = split(name, "(_t)");
					str = splittenName[splittenName.length-1];//last element
					//print("str: "+str);
					timeStr = substring(str, 0, indexOf(str, timeDelimiter));
					//print("posStr: "+posStr);
					n = parseInt(timeStr);
					nframes = maxOf(nframes, n);
					j++;
					//nframes++;
				}
				if (j==nFiles) break;
			}
		}
		frameNumbers[k] = nframes;
		print("nframes["+k+"] = "+ nframes);
	}
	return frameNumbers;
}

function getExtension(filename) {
	if (indexOf(filename, ".")<0) return "";
	s = substring(filename,
			lastIndexOf(filename, "."), lengthOf(filename));
	return s;
}

function initChannelColorIndexes(chns) {
	idx = newArray(chns.length);
	for (i=0; i<chns.length; i++) {
		found = false;
		for (j=0; j<redDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(redDeterminants[j]))>0) {
				idx[i] = 0;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<greenDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(greenDeterminants[j]))>0) {
				idx[i] = 1;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<blueDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(blueDeterminants[j]))>0) {
				idx[i] = 2;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<grayDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(grayDeterminants[j]))>0) {
				idx[i] = 3;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<cyanDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(cyanDeterminants[j]))>0) {
				idx[i] = 4;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<magentaDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(magentaDeterminants[j]))>0) {
				idx[i] = 5;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<yellowDeterminants.length; j++) {
			if (indexOf(toLowerCase(chns[i]),
					toLowerCase(yellowDeterminants[j]))>0) {
				idx[i] = 6;
				found = true;
				break;
			}
			if (found) continue;
		}
	}
	//for (i=0; i<idx.length; i++) {
	//	print("channelIndexes["+i+"] = "+idx[i]);
	//}
	return idx;
}

function computeColorIndexes(chns, outputColors) {
	print("\ncomputeColorIndexes(chns, outputColors):");
	for (i=0; i<chns.length; i++) {
		print("chns["+i+"] = "+chns[i]);
		print("outputColors["+i+"] = "+outputColors[i]);
	}
	nchn = chns.length;
	clrIndexes = newArray(nchn);
	for (i=0; i<nchn; i++) {
		for (j=0; j<chns.length; j++) {
			if (chns[i]==chns[j]) {
				clrIndexes[i] = colorIndex(outputColors[j]);
				break;
			}
		}
	}
	return clrIndexes;
}

//to manage colors for each series independently
function getChannelColorIndexesSeriesBySeries(imageList) {
	//complicated because no 2D arrays in IJ macro language
}

/** To be invoked for each series independently to avoid attempts merging
 * two images in the same channel; channels have to be chosen in the
 * {"c1", ..., "c7"} set and must be different from each other, as in the 
 * Image>Color>"Merge Channels..." command. */
function ensureColorIndexesAreDifferent(colourIndexes) {
	nchn = colourIndexes.length;
	clrIndexes = newArray(nchn);
	for (i=0; i<nchn; i++) {
		clrIndexes[i] = colourIndexes[i];
	}
	for (i=0; i<nchn; i++) {
		c=0;
		for (j=i+1; j<nchn; j++) {//cycle until a free index is found
			if (clrIndexes[j] == colourIndexes[i]) {
				c++;
				clrIndexes[j] += 1;
				if (clrIndexes[j] == 7) clrIndexes[j] = 0;
			}
			if (c==6) break;
		}
	}
	return clrIndexes;
}

/** returns the array of channels in growing order of c1, c2, ..., c7
 * param chns: the channel names array to be reordered
 * param channelCompositeStrings: the array of "c"+i strings, i=1,7
 * 		defining channel colors and positions in the composite image */
function reorderChannels(chns, channelCompositeStrings) {
	nchn = chns.length;
	reorderedChannels = Array.copy(chns);
	chnPositions = newArray(nchn);
	for (i=0; i<nchn; i++) {
	 	chnPositions[i]=parseInt(substring(channelCompositeStrings[i],1));
	}
	for (i=0; i<nchn; i++) {
		for (j=i; j<nchn; j++) {
			if (chnPositions[j] < chnPositions[i]) {
				tmp = chnPositions[j];
				chnPositions[j] = chnPositions[i];
				chnPositions[i] = tmp;
				tmp = reorderedChannels[j];
				reorderedChannels[j] = reorderedChannels[i];
				reorderedChannels[i] = tmp;
			}
		}
	}
	for (i=0; i<reorderedChannels.length; i++) {
		//print("reorderedChannels["+i+"] = "+reorderedChannels[i]);
	}
	return reorderedChannels;
}

function hasDuplicateColorIndex(colourIndexes) {
	for (i=0; i<colourIndexes.length; i++) {
		for (j=i+1; j<colourIndexes.length; j++) {
			if (colourIndexes[j]==colourIndexes[i]) return true;
		}
	}
	return false;	
}

function getChannelColors(chns, ensureColorsAreDifferent) {
	//returns an array having "c1","c2",...,"c7" as elements
	idx = initChannelColorIndexes(chns);
	cycle = 1;
	hasDuplicateColor = false;
	while (hasDuplicateColorIndex(idx) && cycle++ < 7) {
		//print("cycle = "+cycle);
		if (ensureColorsAreDifferent)
			idx = ensureColorIndexesAreDifferent(idx);
		for (i=0; i<idx.length; i++) {
			//print("idx["+i+"] = "+idx[i]);
		}
	}
	for (i=0; i<idx.length; i++) {
		//print("idx["+i+"] = "+idx[i]);
	}
	channelColorIndexes = newArray(idx.length);
	for (i=0; i<idx.length; i++) {
		channelColorIndexes[i] = idx[i];
	}
	clrs = newArray(chns.length);
	for (i=0; i<idx.length; i++) {
		clrs[i] = compositeChannels[idx[i]];
		//print("clrs["+i+"] = "+clrs[i]);
	}
	return clrs;
}

//Traitement Metadata
///////////////////////////////////////////////////////////////////////////////
var MMMetadataEntries = newArray(
//	Description-tag entry		Array-index	Macro-variable				Type
	"pixel-size-x",					//	0	pixelsX						int
	"pixel-size-y",					//	1	pixelsY						int
	"bits-per-pixel",				//	2	bitsPerPixel				int
	"spatial-calibration-state",	//	3	isSpatiallyCalibrated		boolean
	"spatial-calibration-x",		//	4	xCalibration				float
	"spatial-calibration-y",		//	5	yCalibration				float
	"spatial-calibration-units",	//	6	spatialCalibrationIUnit		string
	"image-name",					//	7	mmImageName					string
	"acquisition-time-local",		//	8	acquisitionTimeStr			string
	"modification-time-local",		//	9	modificationTimeStr			string
	"z-position",					//	10	zPosition					float
	"camera-binning-x",				//	11	cameraBinningX				int
	"camera-binning-y",				//	12	cameraBinningY				int
	"_IllumSetting_",				//	13	illumSetting				string
	"_MagSetting_",					//	14	objective					string
	"number-of-planes");			//	15	numberOfPlanes				int

//donnees provenant directement du description-tag
var pixelsX;//int
var pixelsY;//int
var bitsPerPixel;//int
var isSpatiallyCalibrated;//boolean
var xCalibration;//float, 
var yCalibration;//float
var spatialCalibrationIUnit;//string
var mmImageName;//string
var acquisitionTimeStr;//time "20180627 15:41:16.090" -> ms
var acquisitionTime;//time "20180627 15:41:16.090" -> ms
var modificationTimeStr;//time "20180627 15:41:20.483"
var modificationTime;//time "20180627 15:41:20.483"
var zPosition;//float (micron ?)
var zPositionBegin, zPositionEnd;//float (micron ?)
var cameraBinningX;//int
var cameraBinningY;//int
var illumSetting;//string
var objective;//string
var numberOfPlanes;//int

function initializeMetadata() {
	pixelsX = 1;//int
	pixelsY = 1;//int
	bitsPerPixel = 16;//int
	isSpatiallyCalibrated = false;//boolean
	xCalibration = 0;//float, 
	yCalibration = 0;//float
	spatialCalibrationIUnit = "pixel";//string
	mmImageName = "";//string
	acquisitionTimeStr = "";//time "20180627 15:41:16.090" -> ms
	acquisitionTime = 0;//time "20180627 15:41:16.090" -> ms
	modificationTimeStr = "";//time "20180627 15:41:20.483"
	modificationTime = 0;//time "20180627 15:41:20.483"
	zPosition = 0;//float (micron ?)
	zPositionBegin = 0;
	zPositionEnd = 0;//float (micron ?)
	cameraBinningX = -1;//int
	cameraBinningY = -1;//int
	illumSetting = "";//string
	objective = "";//string
	numberOfPlanes = 0;//int
}

function printMetadata() {
	print("pixelsX = "+pixelsX);
	print("pixelsY = "+pixelsY);
	print("bitsPerPixel = "+bitsPerPixel);
	print("isSpatiallyCalibrated = "+isSpatiallyCalibrated);
	print("xCalibration = "+xCalibration);
	print("yCalibration = "+yCalibration);
	print("spatialCalibrationIUnit = "+spatialCalibrationIUnit);
	print("mmImageName = "+mmImageName);
	print("acquisitionTimeStr = "+acquisitionTimeStr);
	print("acquisitionTime = "+acquisitionTime);
	print("modificationTimeStr = "+modificationTimeStr);
	print("modificationTime = "+modificationTime);
	print("zPosition = "+zPosition);
	print("zPositionBegin = "+zPositionBegin);
	print("zPositionEnd = "+zPositionEnd);
	print("cameraBinningX = "+cameraBinningX);
	print("cameraBinningY = "+cameraBinningY);
	print("illumSetting = "+illumSetting);
	print("objective = "+objective);
	print("numberOfPlanes = "+numberOfPlanes);
}

var indexForZPosition;
var searchStartIndex;
/**
 * assigns pixelsX etc. to values found in tag 
 * and returns the new searchStartIndex */
function extractValue(tag, param, searchStartIndex) {
	if (tag=="" || tag==0) return -1;
	//indexOf(string, substring, fromIndex)
	//print("extractValue(tag, param, searchStartIndex)");
	if (indexOf(tag, "MetaMorph") < 0)
		return -1;
	index1 = indexOf(tag, param, searchStartIndex);
	index2 = indexOf(tag, "value=", index1);
	index3 = indexOf(tag, "/>", index2);
	index4 = indexOf(tag, "/>", index3);
	valStr = substring(tag, index2+7, index3-1);
	print(param + " = "+valStr);
	if (param==MMMetadataEntries[0])
		pixelsX = parseInt(valStr);
	else if (param==MMMetadataEntries[1])
		pixelsY = parseInt(valStr);
	else if (param==MMMetadataEntries[2])
		bitsPerPixel = parseInt(valStr);
	else if (param==MMMetadataEntries[3]) {
		isSpatiallyCalibrated = false;
		if (valStr=="on")
			isSpatiallyCalibrated = true;
	}
	else if (param==MMMetadataEntries[4])
		xCalibration = parseFloat(valStr);
	else if (param==MMMetadataEntries[5])
		yCalibration = parseFloat(valStr);
	else if (param==MMMetadataEntries[6])
		spatialCalibrationIUnit = valStr;
	else if (param==MMMetadataEntries[7])
		mmImageName = valStr;
	else if (param==MMMetadataEntries[8])
		acquisitionTimeStr = valStr;
	else if (param==MMMetadataEntries[9]) {
		modificationTimeStr = valStr;
		indexForZPosition = index4;
	}
	else if (param==MMMetadataEntries[10])
		zPosition = parseFloat(valStr);
	else if (param==MMMetadataEntries[11])
		cameraBinningX = parseInt(valStr);
	else if (param==MMMetadataEntries[12])
		cameraBinningY = parseInt(valStr);
	else if (param==MMMetadataEntries[13])
		illumSetting = valStr;
	else if (param==MMMetadataEntries[14])
		objective = valStr;
	else if (param==MMMetadataEntries[15]) {
		numberOfPlanes = parseInt(valStr);
	}
	return index4;
}

function getDescriptionTag(path, IFD, imageID, tiff_tags_plugin_installed) {
	tag = "";
	tagNum = 270;
	if (tiff_tags_plugin_installed) {
		tag = call("TIFF_Tags.getTag", path, tagNum, IFD);
	}
	if (indexOf(tag, "ImageJ")>-1 || IFD==1) {//image ouverte et 
		id = getImageID();
		selectImage(imageID);
		tag = getImageInfo();
		selectImage(id);
	}
/*
	else {//Ancien
		if (IFD==1) {
			id = getImageID();
			selectImage(imageID);
			tag = getImageInfo();
			selectImage(id);
		}
	}
*/
	print("tag:");
	print(tag);
	return tag;
}

function getImageMetadata(path, imageID, tiff_tags_plugin_installed) {
	//public static String getTag(String path, int tag, int ifd);
	tagNum = 270;
	IFD = 1;
	tag = getDescriptionTag(path, IFD, imageID, tiff_tags_plugin_installed);
	//print("getImageMetadata(path, imageID, tiff_tags_plugin_installed)");
	//print("tag:");
	//print(tag);
	if (tag=="" || tag==0) return false;
	//if (!startsWith(tag, "<MetaData>")) return false;
	if (indexOf(tag, "<MetaData>")<0) return false;
	//print("getImageMetadata(path, imageID, tiff_tags_plugin_installed)");
	searchStartIndex = 0;
	for (i=0; i<MMMetadataEntries.length; i++) {
	 	searchStartIndex = extractValue(tag,
	 									MMMetadataEntries[i],
	 									searchStartIndex);
		//print("searchStartIndex = "+searchStartIndex);
		//print("MMMetadataEntries["+i+"] = "+MMMetadataEntries[i]);
		//print("acquisitionTimeStr = "+acquisitionTimeStr);
	 	if (searchStartIndex==-1) return false;
	}
	if (numberOfPlanes>1 && tiff_tags_plugin_installed) {
		zPositionBegin = zPosition;
		tag = call("TIFF_Tags.getTag", path, tagNum, numberOfPlanes);
		//if (!startsWith(tag, "<MetaData>")) return false;
//	//	if (indexOf(tag, "<MetaData>")<0) return false;
		if (indexOf(tag, "<MetaData>")<0)
			print("Could not determine z-calibration");
		extractValue(tag, "z-position", indexForZPosition);
		zPositionEnd = zPosition;
		//print("acquisitionTimeStr = "+acquisitionTimeStr);
	}
	print("acquisitionTimeStr = "+acquisitionTimeStr);
	return true;
}

function computeZInterval() {
	if (numberOfPlanes<2) return 0;
	ZInterval = abs(zPositionEnd - zPositionBegin) / (numberOfPlanes-1);
	return ZInterval;
}

//ajout variables:
var acquisitionYear, acquisitionMonth;
function computeAcquisitionDayAndTime(timeStr) {
	if (timeStr=="" || timeStr==0) return false;
	acquisitionDay = NaN;
	acquisitionTime = NaN;
	//print("timeStr = "+timeStr);
	date = substring(timeStr, 0, 8);
	year = parseInt(substring(date, 0, 4));
	month = parseInt(substring(date, 4, 6));
	day = parseInt(substring(date, 6, 8));
	tStr = substring(timeStr, 9, lengthOf(timeStr));
	//print("tStr = "+tStr);
	hourOfDay = parseInt(substring(tStr, 0, 2));
	minute = parseInt(substring(tStr, 3, 5));
	second = parseInt(substring(tStr, 6, 8));
	//print(substring(tStr, 9, 11));
	millisecond = parseInt(substring(tStr, 9, 12));
	//print("year = "+year);
	//print("month = "+month);
	//print("day = "+ day);
	//print("hourOfDay = "+hourOfDay);
	//print("minute = "+minute);
	//print("second = "+second);
	//print("millisecond = "+millisecond);
	timeMillis = millisecond+(second+(minute+hourOfDay*60)*60)*1000;
	acquisitionYear = year;
	acquisitionMonth = month;
	acquisitionDay = day;
	acquisitionTime = timeMillis;
	return true;
}

/** Converts oldUnit value to newUnit
 *  Does nothing if oldUnit or newUnit is unknown */
function recalculateVoxelDepth(value, oldUnit, newUnit) {
	val = value;
	if (newUnit=="nm") {
		if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm") val *= 1000;
		else if (oldUnit=="mm") val *= 1000000;
		else if (oldUnit=="cm") val *= 10000000;
		else if (oldUnit=="m") val *= 1000000000;
	}
	else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm") {
		if (oldUnit=="nm") val /= 1000;
		else if (oldUnit=="mm") val *= 1000;
		else if (oldUnit=="cm") val *= 10000;
		else if (oldUnit=="m") val *= 1000000;
	}
	else if (newUnit=="mm") {
		if (oldUnit=="nm") val /= 1000000;
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm") val /= 1000;
		else if (oldUnit=="cm") val *= 10;
		else if (oldUnit=="m") val *= 1000;
	}
	else if (newUnit=="cm") {
		if (oldUnit=="nm") val /= 10000000;
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm") val /= 10000;
		else if (oldUnit=="mm") val /= 10;
		else if (oldUnit=="m") val *= 100;
	}
	else if (newUnit=="m") {
		if (oldUnit=="nm") val /= 1000000000;
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm") val /= 1000000;
		else if (oldUnit=="mm") val /= 1000;
		else if (oldUnit=="cm") val /= 100;
	}
	return val;
}

function computeMonthLengths(year) {
	lengths = newArray(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	/** adapted from https://fr.wikipedia.org/wiki/Ann%C3%A9e_bissextile :
	 *  l'année est bissextile (a 366 jours) :
	 *	si elle est divisible par 4 et non divisible par 100
     *	ou si elle est divisible par 400. */
	bisextile = year%4==0 && year%100!=0 || year%400==0;
	if (bisextile) lengths[1] = 29;
	return lengths;
}

/** Computes number of days between two timepoints
 *  acquisitionYears, acquisitionMonths, acquisitionDays: arrays of dimension 2; 
 *  first element --o-> timepoint 0, second element--o-> timepoint 1 */
function daysInterval(Years, Months, Days) {
	monthLengths0 = computeMonthLengths(Years[0]);
	monthLengths1 = computeMonthLengths(Years[1]);
	nDays = 0;
	if (Years[1]==Years[0]) {
		if (Months[1]==Months[0]) {
			return Days[1]-Days[0];
		}
		else {
			nDays = Days[1]-1;
			for (j=Days[0]; j<monthLengths0[Months[0]]; j++) {
				nDays++;
			}
			for (i=Months[0]+1; i<Months[1]; i++) {
				nDays += monthLengths0[i]; 
			}
			print("nDays = "+nDays);
			return nDays;
		}
	}
	return 0;//1 ?
}

/** Returns time interval in ms between first frame and last frame
 *  Fails if timelapse crosses year */
function computeTimelapseDuration(acquisitionYears, acquisitionMonths, 
		acquisitionDays, acquisitionTimes) {
	//dt = 0;
	print("acquisitionTimes[1] = "+acquisitionTimes[1]);
	print("acquisitionTimes[0] = "+acquisitionTimes[0]);//0
	dt = acquisitionTimes[1] - acquisitionTimes[0];
	days = acquisitionDays[1] - acquisitionDays[0];
	months = acquisitionMonths[1] - acquisitionMonths[0];
	years = acquisitionYears[1] - acquisitionYears[0];
	if (days>0 && months==0) //crossing days but not month(s)
		dt += days*24*60*60*1000;
	else if (years==0 && months!=0) {//crossing month(s) but not years
		days = daysInterval(acquisitionYears,
				acquisitionMonths,
				acquisitionDays);
		dt += days*24*60*60*1000;
	}
	print("dt = "+dt);
	return dt;
}

/** Returns time interval in ms between first frame and last frame
 *  Fails if timelapse crosses month
 *  Obsolete; use computeTimelapseDuration instead */
function computeTimelapseDuration_OLD(acquisitionDays, acquisitionTimes) {
	dt = 0;
	//print("acquisitionTimes[1] = "+acquisitionTimes[1]);
	//print("acquisitionTimes[0] = "+acquisitionTimes[0]);
	dt = acquisitionTimes[1] - acquisitionTimes[0];
	days = acquisitionDays[1] - acquisitionDays[0];
	if (days>0) //crossing days but not any month
		dt += days*24*60*60*1000;
	else if (days<0) {//crossing month; le test est faillible
		//traiter le cas
		//faire un tableau des longueurs des mois tenant compte
		//des annees bisextiles
	}
	print("dt = "+dt);
	return dt;
}

//A garder (peut etre utile)
function extractValueAsString(tag, param) {
	//print(tag);
/*
	tokens=split(tag, "(> <)");
	for (i=0; i<tokens.length; i++) {
		tokens[i] = "<"+tokens[i];
		tokens[i] = tokens[i]+">";
		//print(tokens[i]);
	}
*/
	if (indexOf(tag, "MetaMorph") < 0)
		return "Unknown Metamorph Image Format";
	index1 = indexOf(tag, param);
	index2 = indexOf(tag, "value=", index1);
	index3 = indexOf(tag, "/>", index2);
	str = substring(tag, index2+7, index3-1);
	print(param + " = "+str);
	return str;
}
//////////////////////////////////////////////////////////////////////////
//Traitement Metadata : Fin


function processFolder() {
	setBatchMode(true);
	filterExtensions = isExtensionFilter(fileFilter);
	print("filterExtensions = "+filterExtensions);
	nSeries = seriesNames.length;
	print("processFolder(): nSeries = "+nSeries);
	ismultiposition = false;
	istimeseries = false;
	nChannels = 1;
	nPositions = 1;
	nFrames = 1;
	//print("\nseriesNames:");
	//for (i=0; i<seriesNames.length; i++) print(seriesNames[i]);
	for (i=0; i<doSeries.length; i++) {
		print("doSeries["+i+"] = "+doSeries[i]);
	}
	print("\nProcessing series:");
	fF = fileFilter;
	//isseiesFilter = isSeriesFilter(fF);
	//print("isseiesFilter = "+isseiesFilter);
	positionIndex3 = 0;
	firstTime = true;//demande une seule fois pour tout le run
	for (i=0; i<seriesNames.length; i++) {
		initializeMetadata();
		voxelDepth = userVoxelDepth;
		foundZInterval = false;
		//print("\ndoSeries["+i+"] = "+doSeries[i]);
		if (!doSeries[i]) {
			positionIndex3 += positionNumbers[i];
			continue;
		}
		//if (isSeriesFilter(fF) && indexOf(seriesNames[i], fF)<0) continue;
		pixelSize = 1;
		xyUnit = "pixel";
		isXYcalibrated = false;
		print("\nProcessing "+seriesNames[i] + ":");
		type = "16-bit";
		type = imageTypes[i];
		//width = imageWidhs[i];
		//height = imageHeights[i];
		//width = maxImageWidhs[i];
		//height = maxImageHeights[i];
		if (maxImageWidhs[i]==0 || maxImageHeights[i]==0) {
			print("An error occurred in determining series max image width"+
					" and height: skipped");
			continue;
		}
		//imageDepths = newArray(nSeries);//N'EST PAS UTILISE POUR LE MOMENT
		fnames = split(seriesFilenamesStr[i], ",");
		//nFilesInSeries = fnames.length;
		nFilesInSeries = seriesFileNumbers[i];//~ supra
		print("nFilesInSeries = "+nFilesInSeries);
		channelGroupIndex = seriesChannelGroups[i];
		print("channelGroupIndex = "+channelGroupIndex);
		doChannels = toArray(doChannelsFromSequences[channelGroupIndex], ",");
		for (k=0; k<doChannels.length; k++) {
			print("doChannels["+k+"] = "+doChannels[k]);
		}
		nChannels = 0;
		for (c=0; c<doChannels.length; c++) {
			if (doChannels[c]) nChannels++;
		}
		//channels = getChannelNames(fnames, seriesNames[i]);//ancien
		channelsToDo = toArray(seriesChannelSequences[i], ",");//nouveau
		print("ProcessFolder(): seies number "+i+":");
		chnColors = toArray(
			channelSequencesColors[channelGroupIndex], ",");
		chnSaturations = toArray(
			channelSequencesSaturations[channelGroupIndex], ",");
		for (cc=0; cc<chnSaturations.length; cc++) {
			print("chnSaturations["+cc+"] = "+chnSaturations[cc]);//OK
		}
		for (k=0; k<chnColors.length; k++) {
			print("chnColors["+k+"] = "+chnColors[k]);
		}
		//channels, seiesColors, saturations... doivent etre reduits aux 
		//elements pour lesquels doChannels = true
		channels = newArray(nChannels);
		seiesColors = newArray(nChannels);
		saturations = newArray(nChannels);
		k=0;
		for (c=0; c<channelsToDo.length; c++) {
			if (doChannels[c]) {
				channels[k] = channelsToDo[c];
				seiesColors[k] = chnColors[c];
				saturations[k] = chnSaturations[c];
				k++;
			}
		}
		print("nChannels = "+nChannels);
		for (k=0; k<nChannels; k++) {
			print(channels[k]);
			print(seiesColors[k]);
			print(saturations[k]);
		}
		channelColorIndexes = computeColorIndexes(channels, seiesColors);
		for (k=0; k<channels.length; k++) {
			print("channelColorIndexes["+k+"] = "+channelColorIndexes[k]);
		}
		channelColorIndexes = ensureColorIndexesAreDifferent(
					channelColorIndexes);
		print("channelColorIndexes.length = "+channelColorIndexes.length);
		print("Channels to do:");
		for (k=0; k<channels.length; k++) {
			print("channels["+k+"] = "+channels[k]);
			print("channelColorIndexes["+k+"] = "+channelColorIndexes[k]);
		}
		print("seiesColors.length = "+seiesColors.length);
		print("Channel colors:");
		for (k=0; k<channels.length; k++) {
//			print(usedChannels[k] + " : "+
//					compositeChannels[channelColorIndexes[k]]);
			//print(channelsToDo[k] + " : "+colors[channelColorIndexes[k]]);
			print(channels[k] + " : "+colors[channelColorIndexes[k]]);
			print("saturations[k] = "+saturations[k]);
		}
		compositeStrs = newArray(nChannels);//ancien
		//compositeStrs = newArray(channelsToDo.length);
		for (k=0; k<channels.length; k++) {
		//for (k=0; k<channelsToDo.length; k++) {
			compositeStrs[k]=compositeChannels[channelColorIndexes[k]];
			print("compositeStrs["+k+"] = "+compositeStrs[k]);
		}
		//to be merged, channels must be reordered by increasing c numbers
		reorderedChannels = reorderChannels(channels, compositeStrs);
		for (c=0; c<nChannels; c++) {
			print("reorderedChannels["+c+"] = "+reorderedChannels[c]);
		}
		//extensions = getExtensions(list, seriesNames[i]);
		extensions = getExtensions(fnames, seriesNames[i]);
		print("extensions:");
		for (c=0; c<extensions.length; c++)
			print(extensions[c]);
		//ismultiposition = isMultiPosition(list, seriesNames[i]);
		ismultiposition = isMultiPosition(fnames, seriesNames[i]);
		if (ismultiposition)
			print("isMultiposition = true");
		//nPositions = getPositionsNumber(list, seriesNames[i]);
		nPositions = positionNumbers[i];
		print("nPositions = "+nPositions);
//		istimeseries = isTimeSeries(list, seriesNames[i]);
		istimeseries = isTimeSeries(fnames, seriesNames[i]);
		if (istimeseries)
			print("isTimeSeries = true");
		//if (isTimeFilter(fF)) istimeseries = false;
		//	print("isTimeSeries = false");

		nFrames = getFramesNumber(fnames, seriesNames[i]);
		nframesInChannels = getFrameNumbers(fnames, i);
		print("nFrames = "+nFrames);
		seriesName = seriesNames[i];
		str1 = seriesName;
		str2 = "";
		str3 = "";
		str4 = "";
		foundAcquisitionTime = true;
		if (istimeseries) {
			//acquisitionDays = newArray(nFrames);
			//acquisitionTimes = newArray(nFrames);
			acquisitionYears = newArray(2);
			acquisitionMonths = newArray(2);
			acquisitionDays = newArray(2);
			acquisitionTimes = newArray(2);
		}
		//type="16-bit"; 
//		nchannels=1; depth=1; nframes=1;
//		type="8-bit"; width=1; height=1; nchannels=1; depth=1; nframes=1;
//		firstTime = true;//demande a chaque serie ou un fichier est introuvable
		doZprojs = doZprojForChannelSequences[channelGroupIndex];
		projTypes = toArray(
					projTypesForChannelSequences[channelGroupIndex], ",");
		pp = 0;
		for (j=0; j<userPositionsSeriesBySeries.length; j++) {
			//print("positionExists["+j+"] = "+positionExists[j]);
			//print("userPositionsSeriesBySeries["+j+"] = "
			//+userPositionsSeriesBySeries[j]);
		}
		//print("positionNumbers["+i+"] = "+positionNumbers[i]);
		positionIndex2 = 0;
		print("\npositionIndex3 = "+positionIndex3);
		for (j=positionIndex3; j<positionIndex3+positionNumbers[i]; j++) {
			print("userPositionsSeriesBySeries["+j+"] = "+
					userPositionsSeriesBySeries[j]);
			positionIndex2++;
			if (!positionExists[j] || userPositionsSeriesBySeries[j]==0) {
				//positionIndex3 += positionNumbers[j];
				continue;
			}
			if (userPositionsSeriesBySeries[j]==0) {
				//positionIndex3++;
				continue;
			}
			//if (!isCompletePosition[j]) continue;//probleme
			if (positionIndex2==(positionNumbers[i])+1) break;
			if (ismultiposition) {
				str3 = userPositionsSeriesBySeries[j];
				//if-block behaviour depends on operand order!!!
				//if (!isUserPosition || isPositionFilter(fF)
				if (isPositionFilter(fF)
					&& indexOf(str3+"_", fF)<0
					&& indexOf(str3+".", fF)<0) {
					//print("Position "+p+" skipped");
					continue;
				}
				else
					pp++;
				print("Processing position "+userPositionsSeriesBySeries[j]);
				//print("Processing position "+p);
				//print("pp = "+pp);
			}
			nslices = 1;
			tt = 0;
			for (t=1; t<=nFrames; t++) {
				if (istimeseries) {
					str4 = "_t" + t;
					if (isTimeFilter(fF)
									&& indexOf(str4+"_", fF)<0
									&& indexOf(str4+".", fF)<0) {
						print("skip timepoint t = "+t);
						continue;
					}
					else
						tt++;
					//print("Processing "+str4);
				}
				channelsStr = "";
				nimg = 0;
				depths = newArray(nChannels);
				imgIDs = newArray(nChannels);
				imgTitles = newArray(nChannels);
				maxDepth = 1;
/*
				cc = 0;
				for (c=0; c<channelsToDo.length; c++) {
					if (!doChannels[c]) {
						continue;
					}
				cc++;
*/
				for (c=0; c<nChannels; c++) {//a
					//if (nChannels>1) {
						//str2 = reorderedChannels[c];//permute les canaux
						str2 = channels[c];//semble ok
						//print("reorderedChannels["+c+"] = "+
						//		reorderedChannels[c]);
						//str2 = usedChannels[c];
						if (isWaveFilter(fF) && indexOf(str2, fF)<0) {
							continue;
						}
						if (nFrames>1 && nframesInChannels[c]==1 &&
								ignoreSingleTimepointChannels) {
							nChannels--;
							continue;
						}
					//}
					fn = str1+str2+str3+str4+extensions[c];
					//print("fn = "+fn);
					path = dir1+fn;
					print(""+fn);
					if (!File.exists(path)) {
//					if (!File.exists(path) && width>1) {
						error = "Cannot find file\n"+dir1+"\n"+fn;
						print(error);
/*
						//desactive car mieux vaut continuer quoi q'il arrive
						if (firstTime) {
							if (!getBoolean(error+"\nContinue?")) {
								print("Interrupted by user because:");
								print(error);
								finish();
								exit();
							}
						}
*/
						firstTime = false;
//						if(nImages>0) run("Close All");
//						continue;
						//newImage("", type, width, height,
						//		activeChannels, depth, nframes);
						print("Creating black image to replace missing one");
						width = maxImageWidhs[i];
						height = maxImageHeights[i];
				//		width = imageWidhs[i];
				//		height = imageHeights[i];
						print("width = "+width+"     height = "+height);
						newImage("", type, width, height,
								nchannels, depth, nframes);//channelsToDo.length
						//newImage("", type, width, height,
						//		channelsToDo.length, depth, nframes);
						fontSize = 12;
						setFont("SanSerif", fontSize, "Bold");
						texts = newArray(5);
						texts[0] = "FILE NOT FOUND";
						texts[1] = "Input dir:";
						texts[2] = dir1;
						texts[3] = "Filename:";
						texts[4] = fn;
						textWidth = 0;
						textWidths = newArray(5);
						for (k=0; k<texts.length; k++) {
							textWidths[k] = getStringWidth(texts[k]);
						}
						for (k=0; k<texts.length; k++) {
							if (textWidths[k]>textWidth)
								textWidth = textWidths[k];
						}
						factor = width*0.97/textWidth;
						fontSize *= factor;
						setFont("SanSerif", fontSize, "Bold");
						//if (doZproj) depth=1;//pb if avg
						for (z=1; z<=depth; z++) {
							for (k=0; k<texts.length; k++) {
								setSlice(z);
								drawString(texts[k],
										1+(width-textWidths[k]*factor)/2,
										(k+1)*(height-10)/5);
							}
						}
					}
					else {
						if (lastSlice < firstSlice) {
							lastSlice = firstSlice;
						}
						if (firstSlice<1 || lastSlice<1) {
							IJ.redirectErrorMessages();
							open(path);
						}
//						else if (firstSlice>=1 && lastSlice>=1) {
//							open(path, firstSlice);
//						}
						else {
							IJ.redirectErrorMessages();
							open(path, firstSlice);
							slices = lastSlice - firstSlice + 1;
							if (slices>1) {
								for (s=firstSlice+1; s<=lastSlice; s++) {
									IJ.redirectErrorMessages();
									open(path, s);
									run("Select All");
									run("Copy");
									if( nImages>0) close();
									run("Add Slice");
									run("Paste");
									run("Select None");
								}
							}
						}
						currentWidth = getWidth();
						currentHeight = getHeight();
						currentDepth = nSlices;
						maxWidth = maxImageWidhs[i];
						maxHeight = maxImageHeights[i];
						doResize = false;
						if (currentWidth!=maxWidth || currentHeight!=maxHeight) {
							doResize = true;
							print("currentWidth = "+currentWidth);
							print("currentHeight = "+currentHeight);
							print("currentDepth = "+currentDepth);
							print("maxWidth = "+maxWidth);
							print("maxHeight = "+maxHeight);
							print("Resizing image");
/*May not work in some cases because of a bug in ij.plugin.Resizer,
debuged by Marcel Boeglin 2019/05/07 (mail to Wayne Rasband)*/
							run("Size...", "width="+maxWidth+" height="+maxHeight
							+" depth="+nSlices+" average interpolation=None");
						}
					}
					if (nImages==0) break;
					Stack.getDimensions(width, height,
										nchannels, depth, nframes);
					if (doResize) {
						print("After Resizing image");
						print("width = "+width);
						print("height = "+height);
						print("depth = "+depth);
						print("nframes = "+nframes);
					}
					nimg++;
					bitdepth = bitDepth();
					type = getImageType(bitdepth);
					Stack.getDimensions(w, h, nchn, nslices, frames);
					if (nslices>maxDepth) maxDepth = nslices;
					depths[c] = nslices;
					ID = getImageID();
					imageInfo = getImageInfo();
					//print(substring(imageInfo, 0, 100));
					//! binning may be different for each channel
					//if (pp==1 && tt==1) getXYCalibration(imageInfo);
					print("i = "+ i+"  j = "+j+"   t = "+t+"   c= "+c);
					if (t==1 && (c==0 || c==1)) {
						//print("i = "+ i+"  j = "+j+"   t = "+t+"   c= "+c);
						imageID = getImageID();
						if (getImageMetadata(path, imageID,
								tiff_tags_plugin_installed)) {
							print("");
							print("isSpatiallyCalibrated = "+
									isSpatiallyCalibrated);
							voxelWidth = xCalibration;
							voxelHeight = yCalibration;
							xyUnit = spatialCalibrationIUnit;
							if (xyUnit=="um") xyUnit = "micron";
							if (isSpatiallyCalibrated) isXYcalibrated = true;
							print("voxelWidth = "+voxelWidth);			
							print("xyUnit = "+xyUnit);			
							voxelDepth = computeZInterval();
							foundZInterval = true;
							//voxelDepth = ZInterval;
							computeAcquisitionDayAndTime(acquisitionTimeStr);
							print("acquisitionTimeStr = "+acquisitionTimeStr);
							foundAcquisitionTime = true;
						}
						//print("ZInterval = "+ZInterval);
						print("voxelDepth = "+voxelDepth);
						print("acquisitionTime = "+acquisitionTime);
						print("");
						//if (true) {
						if (istimeseries) {
							acquisitionYears[0] = acquisitionYear;
							acquisitionMonths[0] = acquisitionMonth;
							acquisitionDays[0] = acquisitionDay;
							acquisitionTimes[0] = acquisitionTime;
						}
					}
					if (istimeseries && t==nFrames && (c==0 || c==1)) {
						//print("\ni = "+ i+"  j = "+j+"   t = "+t+"   c= "+c);
						print("");
						imageID = getImageID();
						if (getImageMetadata(path, imageID, 
												tiff_tags_plugin_installed)) {
							print("isSpatiallyCalibrated = "+
												isSpatiallyCalibrated);
							if (isSpatiallyCalibrated) isXYcalibrated = true;
							voxelWidth = xCalibration;
							voxelHeight = yCalibration;
							xyUnit = spatialCalibrationIUnit;
							if (xyUnit=="um") xyUnit = "micron";
							voxelDepth = computeZInterval();
							print("voxelWidth = "+voxelWidth);			
							print("xyUnit = "+xyUnit);			
							foundZInterval = true;
						}
						//print("ZInterval = "+ZInterval);
						print("voxelDepth = "+voxelDepth);
						print("");
						computeAcquisitionDayAndTime(acquisitionTimeStr);
						foundAcquisitionTime = true;
						acquisitionYears[1] = acquisitionYear;
						acquisitionMonths[1] = acquisitionMonth;
						acquisitionDays[1] = acquisitionDay;
						acquisitionTimes[1] = acquisitionTime;
					}
					//print("pp = "+pp);
					//ne calculer acquisitionTime que pour t==1 et t==nFrames
					if (doZprojs && nslices>1) {//doZproj: faux
						run("Z Project...", "projection=["+projTypes[c]+"]");
						if (to32Bit) run("32-bit");
						nslices = 1;
						projID = getImageID();
						selectImage(ID);
						if( nImages>0) close();
						selectImage(projID);
					}
					imgIDs[c] = getImageID();
					imgTitles[c] = getTitle();
					//! binning may be different for each channel
					channelsStr += compositeStrs[c]+"=["+imgTitles[c]+"]";
				}
				if (nimg==0) continue;
				//print("doZprojs = "+doZprojs);
				//print("maxDepth = "+maxDepth);
				if (!doZprojs && maxDepth>1) {//doZproj: faux
					heterogeneousZDims = false;
					//print("\n \nCHECKING z dimensions");
					for (q=0; q<depths.length; q++) {
						//print("depths[q] = "+depths[q]);
						for (r=q+1; r<depths.length; r++) {
							if (depths[r] != depths[q]) {
								heterogeneousZDims = true;
								break;
							}
						}
					}
					if (heterogeneousZDims) {
						for (q=0; q<depths.length; q++) {
							if (depths[q]<maxDepth &&depths[q]>1) {
								selectImage(imgIDs[q]);
								completeStackTo(maxDepth);
								nslices = maxDepth;
							}
							else if (depths[q]==1) {
								selectImage(imgIDs[q]);
								singleSectionToStack(maxDepth);
								nslices = maxDepth;
							}
						}
					}
				}
				if (nimg>1) {
					//! binning may be different for each channel
					IJ.redirectErrorMessages();
					run("Merge Channels...", channelsStr+" create");
				}
				else {
					//print("c = "+c);
					//print("cc = "+cc);
					//mettre la couleur du canal
					//run(colors[channelColorIndexes[cc]]);
					//marche pas ou defait + loin
				}
				rename("t"+t);
				if (istimeseries && nFrames>1) {
					//print("t = "+t);
					//print("tt = "+tt);
					if (!oneOutputFilePerTimePoint) {
						if (tt==2)
							run("Concatenate...",
								"open image1=t1 image2=t2");
						if (tt>2)
							run("Concatenate...",
								"open image1=Untitled image2=t"+t);
					}
					else {
						//rename(seriesNames[i]+"_s"+p+"_t"+t);
						rename(seriesNames[i]+
								userPositionsSeriesBySeries[j]+"_t"+t);
						if (nChannels*nslices > 1) {
							Stack.setDimensions(nChannels, nslices, 1);
						}
						id = getImageID();
						enhanceContrast(id, saturations);
						id = getImageID();
						labelChannels(id, reorderedChannels);
						Stack.getDimensions(w,h,nch,slices,frames);
						if (nch==1) {
							//print("run("+colors[channelColorIndexes[0]]+")");
							//run(colors[channelColorIndexes[0]]);//obsolete
							//getLUT() finds LUT if wavelength not in filename
							lutName = getLUT(illumSetting);
							run(lutName);
						}
						setMetadata("Info", info);
						outname = str1+str3+str4;
						outdir = dir2;
						if (createFolderForEachOutputSeries) {
							outdir = outdir + "\\" + outname + "\\";
							//print("1ere occurence : outdir = "+outdir);
							File.makeDirectory(outdir);
						}
						saveAs("tiff", outdir+outname+".tif");
						//saveAs("tiff", dir2+str1+str3+str4+".tif");//old
						if( nImages>0) close();
						selectWindow("Log");
						saveAs("Text", dir2+"Log.txt");
						continue;
					}
				}
				if (nImages==0) continue;
			}
			if (nImages==0) continue;
//			voxelDepth = userVoxelDepth;
			getDimensions(ww, hh, nch, ns, nf);
			if (ns<2) voxelDepth = 0;
			print("isSpatiallyCalibrated = "+isSpatiallyCalibrated);
			if (isSpatiallyCalibrated) isXYcalibrated = true;
			print("isXYCalibrated = "+isXYcalibrated);
			print("voxelWidth = "+voxelWidth);
			print("voxelDepth = "+voxelDepth);
			print("xyUnit = "+xyUnit);			
			if (isXYcalibrated) {
				//setVoxelSize(voxelWidth, voxelHeight, 0, xyUnit);
				print("voxelWidth = "+voxelWidth);
				print("voxelDepth = "+voxelDepth);
				print("xyUnit = "+xyUnit);
				if (xyUnit!=userLengthUnit) {
					voxelDepth = recalculateVoxelDepth(voxelDepth,
						userLengthUnit, xyUnit);
				}
				setVoxelSize(voxelWidth, voxelHeight, voxelDepth, xyUnit);
				//ImageJ uses same spatial calibration unit for x, y and z
			}
			else {
				setVoxelSize(userPixelSize, userPixelSize,
					voxelDepth, userLengthUnit);
			}
			if (istimeseries && pp==1) {
				if (foundAcquisitionTime) {
					//dt = computeTimelapseDuration_OLD(acquisitionDays,
					//								acquisitionTimes);
					dt =  computeTimelapseDuration(acquisitionYears, 
												acquisitionMonths, 
												acquisitionDays,
												acquisitionTimes);
					print("\ndt = "+dt);
					print("");
					meanFrameInterval = 0;
					if (nFrames>1)
						meanFrameInterval = dt/(nFrames-1);

				}
				else {
					meanFrameInterval = userFrameInterval;
				}
			}
			if (istimeseries && !oneOutputFilePerTimePoint) {
				//print("usedChannels.length = "+usedChannels.length);
				//Stack.setDimensions(usedChannels.length,nslices,nFrames);
				print("nChannels = "+nChannels);
				if (nChannels*nslices*nFrames>1)
					Stack.setDimensions(nChannels, nslices, nFrames);
				//if (channelsToDo.length*nslices*nFrames>1)
				//	Stack.setDimensions(channelsToDo.length, nslices, nFrames);

				if (foundAcquisitionTime && meanFrameInterval>=1) {
					print("meanFrameInterval = "+(meanFrameInterval/1000)+" s");
					Stack.setTUnit("s");
					Stack.setFrameInterval(meanFrameInterval/1000);
				}
				else if (!foundAcquisitionTime) {
					Stack.setTUnit(userTUnit);
					Stack.setFrameInterval(userFrameInterval);
				}
			}
			//rename(seriesNames[i]+"_s"+p);
			rename(seriesNames[i]+userPositionsSeriesBySeries[j]);
			if (isTimeFilter(fF)) {
				//Stack.setDimensions(usedChannels.length, nslices, 1);
				Stack.setDimensions(nChannels, nslices, 1);
				//Stack.setDimensions(channelsToDo.length, nslices, 1);
			}
			id = getImageID();
			//labelChannels(id, channels);
			//labelChannels(id, usedChannels);
			labelChannels(id, reorderedChannels);
			id = getImageID();
			enhanceContrast(id, saturations);
			Stack.getDimensions(w, h, nch, slices, frames)
			if (nch==1) {
				//print("run("+colors[channelColorIndexes[0]]+")");
				//run(colors[channelColorIndexes[0]]);//obsolete
				//getLUT(illumSetting) finds LUT if wavelength not in filename
				lutName = getLUT(illumSetting);
				run(lutName);
			}
			setMetadata("Info", info);
			outname = str1+str3;
			outdir = dir2;
			if (istimeseries && isTimeFilter(fF))
				outname = outname + str4;
			if (createFolderForEachOutputSeries) {
				outdir = outdir + "\\" + outname + "\\";
				//print("2eme occurence : outdir = "+outdir);
				File.makeDirectory(outdir);
			}
			saveAs("tiff", outdir+outname+".tif");
/*
			if (istimeseries && isTimeFilter(fF))
				saveAs("tiff", dir2+str1+str3+str4+".tif");
			else
				saveAs("tiff", dir2+str1+str3+".tif");
*/
			close();
			selectWindow("Log");
			saveAs("Text", dir2+"Log.txt");
		}//end position j
		positionIndex3 += positionNumbers[i];
		printMetadata();
	}//end series i
	print("");
	setBatchMode(false);
}//end processFolder()

/** Returns LUT derived from illumSettingfound in Metadata
 * This method is used to assign channel color of images for which  wavelength
 * is not included in filenames; returned LUTS are: Grays, Red, Green and Blue.*/
function getLUT(illumSetting) {
	if (illumSetting=="" || illumSetting==0)
		return "Grays";
	for (i=0; i<grayDeterminants.length; i++) {
		if (indexOf(illumSetting, grayDeterminants[i])>=0)
			return "Grays";
	}
	for (i=0; i<grayDeterminants.length; i++) {
		if (indexOf(illumSetting, redDeterminants[i])>=0)
			return "Red";
	}
	for (i=0; i<grayDeterminants.length; i++) {
		if (indexOf(illumSetting, greenDeterminants[i])>=0)
			return "Green";
	}
	for (i=0; i<grayDeterminants.length; i++) {
		if (indexOf(illumSetting, blueDeterminants[i])>=0)
			return "Blue";
	}
	return "Grays";
}

function labelChannels(imageID, labels) {
	id = getImageID();
	selectImage(imageID);
	Stack.getDimensions(w, h, nchn, slices, frames);
	if (nchn<2) {
		selectImage(id);
		return;
	}
	if (nchn>labels.length) nchn = labels.length;
	for (c=0; c<nchn; c++) {
		//print("labels["+c+"] = "+labels[c]);
		label = labels[c];
		//print("label = "+label);
		for (z=1; z<=slices; z++) {
			for (t=1; t<=frames; t++) {
				Stack.setPosition(c+1, z, t);
				setMetadata("Label", label);
			}
		}
	}	
	selectImage(id);
}

function enhanceContrast(imageID, saturations) {
	print("Enhancing contrast:");
	for (c=0; c<saturations.length; c++) {
		print("saturations["+c+"] = "+saturations[c]);
	}
	id = getImageID();
	selectImage(imageID);
	Stack.getDimensions(width, height, nchn, slices, frames);
	if (slices>2) Stack.setSlice(slices/2);
	if (frames>2) Stack.setFrame(frames/2);
	for (c=0; c<nchn; c++) {
		if (saturations[c]>0) {
			//print("c+1 = "+(c+1));
			if (nchn>1) Stack.setChannel(c+1);
			saturated = saturations[c];
			//print("saturated = "+saturated);
			run("Enhance Contrast","saturated="+saturated);
		}
	}
	selectImage(id);
}

function singleSectionToStack(nslices) {
	run("Copy");
	for (i=1; i<nslices; i++) {
		run("Add Slice");
		run("Paste");
	}
}

function completeStackTo(nslices) {
	ns = nSlices();
	setSlice(ns);
	for (i=ns; i<=nslices-ns+1; i++) {
		run("Add Slice");
	}
	//print("nSlices = "+nSlices);
}

function getImageType(bitdepth) {
	d = bitdepth;
	if (d==8) return "8-bit";
	else if (d==16) return "16-bit";
	else if (d==24) return "RGB Color";
	else if (d==32) return "32-bit";
	return "";
}

//80 caracteres:
//23456789 123456789 123456789 123456789 123456789 123456789 123456789 1234567890
