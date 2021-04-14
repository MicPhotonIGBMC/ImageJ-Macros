/**
* macro "MetamorphFilesFolderToHyperstacks_"
* Author : Marcel Boeglin, July 2018 - January 2021
* e-mail: boeglin@igbmc.fr
* 
* ¤ Opens Metamorph multi-position time-series z-stacks of up to 7 channels
*	from input folder and saves them as hyperstacks to output folder.
* ¤ Only TIFF and STK files are processed.
* ¤ Image files for which no series name was found are skipped.
* ¤ Single file series (including output files of this macro) are skipped.
* ¤ Series having same channel sequence are grouped in channel groups.
*	Series of a given channel group are processed using same parameters.
* ¤ Channel colors are determined automatically from filennames using red,
*	green, blue, cyan, magenta, yellow and gray determinants but can be
*	changed by the user.
*	For instance, the red determinants set is: {"543", "555", "561",
*	"594", "CY3", "Y3", "DsRed", "mCherry", "N21", "RFP", "TX2"}.
*	Channels containing a red, green, blue or gray determinant in their names
*	are assumed to be respectively red, green, blue or gray.
*	In future versions, it's planned  to get channel colors from metadata
*	in case Metamorph is configured to not add the illumination settings
*	to the filenames (which in that case contain just _w1, _w2, ..., _wn).
*	If none of the color determinants sets works with one of our illumination
*	setting names, just add the missing determinant to the appropriate set.
* ¤ Dual camera channels handling:
*	Assumes channels are saved in separate images. As in single camera
*	acquisitions, colors are derived from filenames. 
*	Dual camera filenames are assumed to be of the type:
*	seriesName_w1Lambda1 Lambda2...
*	seriesName_w2Lambda1 Lambda2...
*	One could expect that w1 corresponds to lambda1 and w2 to lambda2, but
*	w1 may correspond to lambda2 and w2 to lambda1, depending on the
*	configuration of Metamorph.
*	The dual channel separator (a space character in the example) may be
*	different, for instance a "-", depending on how dual camera illumination
*	settings have been named in Metamorph.
*	Dual channel order and separator are managed by the macro but are
*	assumed to be the same for all series in a given folder.
*	If the dual channel colors attribution fails, arbitrary (probably 
*	unwanted) colors are assigned to the channels. In such a case, the
*	user can choose the color of each channel for each channel group.
* ¤ Output images are X, Y, Z and T calibrated if calibration data are
*	available.
* ¤ Allows control of z-range and time-range of input files.
* ¤ Does optional resizing or croping of input files.
* ¤ Does optional maximum z-projection of input files and color balance of
*	output files.
* ¤ In case of heterogeneous z-dimensions between channels and 
*	'Do z-projection' is unchecked, single-section channels are transformed
*	into z-stacks having same depth as channels acquired as z-stacks by
*	duplicating the single-section.
* ¤ Series handling dialog is not displayed if larger than screen (happens
*	if the folder contains more series than can be added as checkboxes in
*	a dialog). In this case all series are assumed to be processed.
* ¤ From version 44a: positions _s1, _s2, _s3 etc can be replaced in output
*	filenames by the position names from seriesMame.nd files.
*
* KNOWN & POSSIBLE PROBLEMS:
* ¤ fails if input image-type=="RGB"; 
*	in this case, only 1 channel possible (not implemented)
* ¤ Temporal calibration fails if timelapse crosses new year.
*	--o-> frame interval = 0 or is wrong
* ¤ Channels handling dialog boxes may be larger than screen if the
*	folder contains numerous series with different channel sequences.
* ¤ Developed under Win7, 8, 10; not tested by the author on Linux and Mac-OS.
*
* DEPENDENCIES:
* Z-calibration needs Joachim Wesner's tiff_tags plugin:
* https://imagej.nih.gov/ij/plugins/tiff-tags.html
* MemoryMonitor_Launcher.jar allowing to launch "Memory" monitor from a macro.
* If one of these plugins is missing, depending service is disabled.
* 
* Author: Marcel Boeglin, 2018-2021.
*/

var version = "44a76";
var osNames = newArray("Mac OS X","Linux","Windows");
var osName = getInfo("os.name");
var dbug = false;//not used
var macroName = "MetamorphFilesFolderToHyperstacks";
var author = "Author: Marcel Boeglin 2018-2021";
var mainMsg = macroName+"\nVersion: "+version+"\n"+author;
var info = "Created by "+macroName+"\n"+author+"\nE-mail: boeglin@igbmc.fr";
var features = "Opens  input folder  image series consisting  in up"+
	"\nto 7 channels  multi-position  time-series  z-stacks"+
	"\nnamed according to Metamorph dimensions order"+
	"\nand saves them as hyperstacks to output folder."+
	"\nCalibrates output images if metadata can be read."+
	"\nInput folder should contain only original images.";
var compositeColors = newArray("red","green","blue",
	"gray","cyan","magenta","yellow");
var compositeChannels = newArray("c1","c2","c3","c4","c5","c6","c7");
var projPrefixes = newArray("AVG_","MAX_","MIN_","SUM_","STD_","MED_");
var projectionTypes = newArray("Average Intensity","Max Intensity",
	"Min Intensity","Sum Slices","Standard Deviation","Median");
var colors = newArray("Red","Green","Blue","Grays",
	"Cyan","Magenta","Yellow");
var colorLutNames = newArray("Red","Green","Blue","Grays",
	"Cyan","Magenta","Yellow");

/* Separator between elements of a 2D array */
var _2DarraysSplitter = "/";

//_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/ TO BE COMPLETED
//To change dialog defaults, modify variables below:

var runMemoryMonitor = true;
/** Add your channel determinants to arrays below to auto-assign colors.
	If a determinant appears in multiple colors, the order of priority is
	red, green, blue, gray, cyan, magenta, yellow. */
var redDeterminants = newArray("543","555","561","594","CY3","Y3",
	"DsRed","mCherry","N21","RFP","TX2");
	//"Y5","633","642","647");//IR in red if no other red channel
var greenDeterminants = newArray("GFP","FITC","488","491");
var blueDeterminants = newArray("405","CFP","CY5","DAPI","HOECHST","Y5",
		"633","642","647");
var grayDeterminants = newArray("BF","DIC","PH","TL","TRANS","POL");
var cyanDeterminants = newArray("CFP");
var magentaDeterminants = newArray("CY5","Y5");
var yellowDeterminants = newArray("YFP");

var machine = "Spinning Disk / Nikon - IGBMC";
/** dualCameraSettingsInMetadata: dual channel settings defined in Metamorph, as
	they appear in image metadata; may be different from those in imagenames! */
var dualCameraSettingsInMetadata = newArray(
	"_w1CSU491 561",//Nikon spinning disk IGBMC
	"_w1CSU491 635",//	"		"		"
	"_w1CSU488_561");//Leica spinning disk IGBMC
/* IGBMC spinning disks: Nikon: "(\\s)", Leica: "_" */
var dualChannelSeparatorInMetadata = "(\\s)";
/* dual channel settings as they appear in image names */
var dualCameraSettingsInImagenames = newArray("_w1CSU491 561","_w1CSU488-561");

/** IGBMC spinning disks: Leica: dualChannelSeparator = "-"
	Nikon: "(\\s)", equivalent to " " (space) */
var dualChannelSeparator = "(\\s)";
var firstDualChannelIllumSetting_is_w1 = true;//to replace by infra
/* invertedDualChannelIllumSettingsOrder
	if true, w1 corresponds to 2nd illum setting */
var invertedDualChannelIllumSettingsOrder = false;
//var isDualChannelSingleImage = false;

var XYZUnitChoices = newArray("pixel","nm","micron","um","µm","mm","cm","m");
var TUnitChoices = newArray("ms","s","min","h");

var allSeriesSameXYZTCalibrations;
var calibrationOption;
var calibrationOptions = newArray("Don't calibrate anything", 
	"Same calibrations for all series","Different calibrations for each series",
	"Get calibration from metadata");
var XYCalibrations, ZCalibrations, TimeIntervals;
var XYZUnits, TUnits;
/* if true, channels for which only 1st timepoint was recorded are ignored */
var ignoreSingleTimepointChannels = true;
/* % saturated pixels for channels in composite output images */
var compositeChannelSaturations = newArray(0.05/*red*/,0.05/*green*/,
	0.05/*blue*/,0.0/*gray*/,0.01/*cyan*/,0.01/*magenta*/,0.01/*yellow*/);

var doSeries;//array(nSeries)
var letMeChooseSeries = true;
var noChannelDependentBinning = true;
var doZproj = true;
var doZprojsByDefault = false;

var displayDataReductionDialog = false;

var resize = false;
var resizeFactor = 0.5;

var crop = false;
var optimizeSpeed = true;
var seriesToCrop;

var firstSlice=1, lastSlice=-1;
var doRangeAroundMedianSlice = false;
var rangeAroundMedianSlice = 50;// % of stack-size

var firstPosition=1, lastPosition=-1;
var startPosition, stopPosition;
var positionNamesFromND;

var useUserTimeCalibration = false;
var firstTimePoint=1, lastTimePoint=-1;//-1 means until nTimepoints
var doRangeFrom_t1 = false;
var rangeFrom_t1 = 50;// % of nTimepoints

//End of variables to be changed to modify dialog defaults.
//_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

var extensionsRegex = "TIF|tif|TIFF|tiff|STK|stk";
var roiX, roiY, roiW, roiH;
var to32Bit = false;

/*
Variables tableaux 2D pour chaque serie sous forme de chaines de caracteres
separees par des virgules. Ex. : 
seriesChannelSequences = newArray(nSeries);
seriesChannelSequences[0] = "_w1CY3,_w2FITC,_w3DAPI";
etc.
Pour chaque serie, le tableau des canaux est reconstruit en utilisant
toArray(str, separator) qui renvoie dans le cas precedent :
seriesChannels = {"_w1CY3","_w2FITC","_w3DAPI"};
*/
/* Array of filenames separated by "'" for each series */
var seriesFilenamesStr;


/* Array of fileNumbers for each series */
var seriesFileNumbers;

/* Array of channelnames separated by _2DarraysSplitter for each series */
var seriesChannelSequences;
/* Array of series channels Numbers */
var seriesChannelNumbers;

/** Array of length the number of different channel sequences;
	its elements are _w1, _w2, ... separated by _2DarraysSplitter */
var channelSequences;

/** Array of length the number of different channel sequences;
	seriesWithSameChannels[i] = names of the series having channelSequences[i],
	separated by _2DarraysSplitter */
var seriesWithSameChannels;

/* Position numbers for each series; array of same length as seriesNames */
var positionNumbers;


/* Array of timepoint strings separated by _2DarraysSplitter for each series */
//PEUT-ETRE INUTILE mais peut servir a voir s'il manque des temps intermediaires
//dans certaines series (mais pas pour certains canaux)
var seriesTimePointsStr;//NOT IMPLEMENTED
/* Array of series timePoints Numbers */
var seriesTimePointNumbers;//NOT IMPLEMENTED
/** isSingleTimepointChannel est a determiner pour chaque serie et chaque canal
	au moment du traitement du dossier
	si isSingleTimepointChannel est vrai pour une position, il devrait l'etre
	pour toutes les positions de la meme serie */
var isSingleTimepointChannel;//NOT IMPLEMENTED


var seriesCompleteness;

//CALCULATED NOWHERE
/** maxImageWidths, maxImageHeights for each series; some channels may have
	been acquired with a binning of 2 or 4;
	these arrays allow to not break processing if 1st images of a series are 
	missing or if a channel has a different binning.
	hese arrays have same length as seriesNames */
var maxImageWidths, maxImageHeights, maxImageDepths;
var imageTypes,	imageWidhs,	imageHeights, imageDepths;
//CALCULATED NOWHERE

/* min and max position number in filtered file list */
var minPosition, maxPosition;

/** userPositions: array(maxPosition - minPosition)
	position names of positions choosen by user */
var userPositions = newArray(1);

/** String array of all positions series by series. 
	Array elements are _s1, _s2, ..., _sS1,  _s1, s2, ..., _sS2, ...
	sS1 is positions number of series 1,
	sS2 positions number of series 2 etc. */
var positionsSeriesBySeries;

/** Boolean arrays positionExists, isCompletePosition (series by series). 
	'exists' means found at least one file with '_s...' in its name;
	'complete' means no File (c, t) is missing in series for this position. 
	These arrays have same length as positionsSeriesBySeries. */
var positionExists, isCompletePosition;
/* String array: userPositions, detailed series by series */
var userPositionsSeriesBySeries;

/* doChannelsFromSequences: array of length the number of channel sequences */
var doChannelsFromSequences;
/* doZprojForChannelSequences: array of length the number of channelxequences */
var doZprojForChannelSequences;
/** projTypesForChannelSequences: array of length the number of channel 
	sequences; retrieve elements using toArray(arrayStr, separator) */
var projTypesForChannelSequences;

/** seriesChannelGroups: array of length nSeries
	values are the channelGroupID (0, 1, channelGroupsNumber) 
	to which belongs each series */
var seriesChannelGroups;

//For channelColorsAndSaturationsDialog():
var channelSequencesColors;
var channelSequencesSaturations;

var nImages0 = nImages;//nb of open images before run
var ndNames; filterFilesWith_ndNames = true;
var filterFilesUsingNDFiles = true;
var fileFilter = "";//includingFilter
var excludingFilter = "";
var channelSuffix = "_w";
var positionSuffix = "_s";
var timeSuffix = "_t";
var dir1, dir2, list;
var allChannels, allChannelColors, allChannelIndexes, allOutputColors;

var nSeries;
var seriesNames;

/** multichannelSeries[i] = true if series i is multiwavelength ie
	imagenames contain "_w1"[, "_w2", ...], possibly only 1 wavelength.
	multipositionSeries[i] = true if series i is multiposition
	timeSeries[i] = true if series i is timeSeries */
var multichannelSeries, multipositionSeries, timeSeries;//rebuildMultiCPTArrays

var nChn, nPositions, nFrames, depth;
var channels, projTypes;
var doChannel;
var channelSaturations;

var imageInfo;
var pixelSizes, xyUnits;
var pixelSize, xyUnit;
var voxelWidths, voxelHeights, voxelDepths;
var voxelWidth, voxelHeight, voxelDepth;
var xUnits, yUnits, zUnits;
var xUnit, yUnit, zUnit;
var sliceNumber, ZInterval, ZUnit;

var userPixelSize, userVoxelDepth, userLengthUnit;
var useUserXYZCalibrations

var frameInterval;
var userFrameInterval, userTimeUnit;
var atLeastOneTimeSeries;
//take in account image-acquisition year, month, day & time:
var acquisitionYear, acquisitionMonth, acquisitionDay, acquisitionTime;

var askForCalibrationsAndUnits;
var channelColorIndexes;

var pluginName = "tiff_tags.jar";
var tiff_tags_plugin_installed = false;

var seriesWithSameChannels;

var realObjective, declaredObjective;
var doPixelSizeCorrection = false;
var pixelSizeCorrection = 1.0;

//.nd fields:
var DoTimelapse;//"DoTimelapse", TRUE
var NTimePoints;//"NTimePoints", 3
var DoStage;//"DoStage", TRUE
var NStagePositions;//"NStagePositions", 2
var DoWave;//"DoWave", TRUE
var NWavelengths;//"NWavelengths", 2
var DoZSeries;//"DoZSeries", TRUE
var NZSteps;//"NZSteps", 21
var WaveInFileName;//"WaveInFileName", TRUE
//macro arrays of ND fields finishing in 1, 2, 3, ...
var WaveNames;//array(NWavelengths)
var WaveDoZs;//array(NWavelengths)

/* AJOUTER dans MMMetadataEntries pour spinning Leica :
"ASI Piezo Z"
"Camera Bit Depth"
et analyser les metadata suivantes:
<custom-prop id="ASI Piezo Z" type="float" value="-35.36"/>
<custom-prop id="ASI Piezo Z" type="float" value="15.48"/>
<custom-prop id="Camera Bit Depth" type="float" value="16"/>
*/
//Metadata
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

//data from description-tag
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

//forbiden chars in Windows filenames: \ / : * ? " < > |

/** Regex meta characters authorized in filenames under Windows. 
	Should create such an array for Linux and Mac OS and use the right one*/
var regexMetachars = newArray("^","$","+","{","}","[","]","(",")",".");// ~ ok
// "." seems unnecessary
var WindowsForbiddenChars = newArray(
		"\\\\","/",":","\\*","\\?","\"","<",">","\\|"
	);
var searchIndexForZPosition;
var fullMode = true;
//print("fullMode = "+fullMode);

/** Allows run in different modes via macros in 'macros' folder
	installed at ImageJ startup by a macro in StartupMacros[.fiji].ijm.
	See Run_MetamorphFilesFolderToHyperstacks.ijm */
var arg = getArgument();
/** Names of images with rois in overlay from which are retrieved regions 
	to be extracted from input images. Roi images must be contained in 
	dir1/ImagesWithRois/ folder. */
var roiImages;
/* roiImages without projection prefixes like "AVG_", "MAX_", "MIN_" etc. */
var prefixLessRoiImages;
var logCount = 0;
var logFiles;

var separationLine = "_/";
for (xx=0; xx<40; xx++) separationLine += "_/";
separationLine = "\n"+separationLine;
requires("1.53f");

execute();

/** Deletes temporary log files created in output dir by this macro to
	avoid it's potentially blocked by Windows if such files are present
	due to aborted previous runs. */
function delete_residual_Tmp_Log_files() {
	//Log_tmp0.txt
	//Log_tmp1.txt
	outDirFiles = getFileList(dir2);
	if (outDirFiles.length==0) return;
	for (i=0; i<outDirFiles.length; i++) {
		fname = outDirFiles[i];
		regex = "Log_tmp\\d*\\.txt";
		path = dir2+fname;
		if (matches(fname, regex)) File.delete(path);
	}
}

/* Returns array of strings separated by 'separator' contained in 'str' */
function toArray(str, separator) {
	if (str=="") return newArray(1);
	return split(str, "("+separator+")");
}

function findFile(dir, filename) {
	lst = getFileList(dir);
	for (i=0; i<lst.length; i++) {
		if (File.isDirectory(""+dir+lst[i]))
			findFile(""+dir+lst[i], filename);
		else {
			if (lst[i]==filename) return true;
		}
	}
	return false;
}

/** Assigns general variables 'minPosition' & 'maxPosition'
	to values found in 'dir1' for series named 'seriesName'
	Assumes at most 10000 x 10000 positions */
function getMinAndMaxPosition(filenames, seriesNameIndex) {
	if (!multipositionSeries[seriesNameIndex]) return 1;
	ts = timeSeries[seriesNameIndex];
	positionDelimiter = ".";
	if (ts) positionDelimiter = "_t";
	nFiles = getFilesNumber(seriesName);
	//print("nFiles in series = "+nFiles);
	j=0;
	minPosition = 100000000;
	maxPosition = 1;
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			splittenName = split(name, "(_s)");
			str = splittenName[splittenName.length-1];
			posStr = substring(str,0,indexOf(str,positionDelimiter));
			n = parseInt(posStr);
			maxPosition = maxOf(maxPosition, n);
			minPosition = minOf(minPosition, n);
			j++;
		}
		if (j==nFiles) break;
	}
}

function isSeriesFilter(fileFilter) {//not used
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

function ndFileNames(filenames) {
	dbg = true;
	nFiles = filenames.length;
	ndNames = newArray(nFiles);
	j=0;
	for (i=0; i<nFiles; i++) {
		fname = filenames[i];
		if (endsWith(fname, ".nd"))
			ndNames[j++] = substring(fname,0,lastIndexOf(fname,".nd"));
	}
	if (dbg) for (i=0; i<j; i++) print("ndNames["+i+"] = "+ndNames[i]);
	return Array.trim(ndNames, j);
}

function filterListWith_ndNames(filenames, ndNames) {
	nND = ndNames.length;
	if (nND==0) return filenames;
	nFiles = filenames.length;
	filenames2 = newArray(nFiles);
	ii=0;
	for (i=0; i<nFiles; i++) {
		fname = filenames[i];
		for (j=0; j<nND; j++) {
			if (startsWith(fname, ndNames[j])) {
				filenames2[ii++] = filenames[i];
				break;
			}
		}
	}
	return Array.trim(filenames2, ii);
}

function execute() {
	dbg=false;
	//askForCalibrationsAndUnits = isKeyDown("alt");
	//print("askForCalibrationsAndUnits = "+askForCalibrationsAndUnits);
	//setKeyDown("none");
	getDirs();
	print("\\Clear");
	doZProj = false;
	if (arg=="EasyMode_Zproj") {
		fullMode = false;
		doZProj = true;
		doZprojsByDefault = true;
	}
	else if (arg=="EasyMode_noZproj") {
		fullMode = false;
		doZProj = false;
		doZprojsByDefault = false;
	}
	else if (arg=="Full_Mode") {
		fullMode = true;
		doZProj = false;
		doZprojsByDefault = false;
	}
	print(mainMsg);
	print("E-mail: boeglin@igbmc.fr");
	print("");
	print(features);
	print("\nExecution:");
	print("arg = "+arg);
	print("fullMode = "+fullMode);
	print("doZprojsByDefault = "+doZprojsByDefault);

	dualCameraDialog();
	dualCameraDialog2();
	fileFilterAndCalibrationParamsDialog();

	pluginsDir = getDirectory("plugins");
	tiff_tags_plugin_installed = findFile(pluginsDir, "tiff_tags.jar");
	if (tiff_tags_plugin_installed)
		print("tiff_tags.jar is installed");
	else
		print("Automatic Z-interval calibration "+
			"needs tiff_tags plugin");
	list = getFiles(dir1);

	print("\nFile list:");
	for (i=0; i<list.length; i++) print(list[i]);

	ndNames = ndFileNames(list);
	if (filterFilesWith_ndNames) list = filterListWith_ndNames(list,ndNames);

	print("\nFile list:");
	for (i=0; i<list.length; i++) print(list[i]);
	//keep only TIFF & STK files matching fileFilter, not excludingFilter
	list = filterList(list, fileFilter, excludingFilter);

	nf = list.length;
	list = removeSinglets(list);//from 43s
	if (list.length==0) {
		showMessage("No images to process after removeSinglets(list)");
		exit();
	}
	if (list.length<nf) {
		print("\nFile list after removeSinglets");
		for (i=0; i<list.length; i++) print(list[i]);
	}
	seriesNames = getSeriesNames(list);

	print("fullMode = "+fullMode);
	if (fullMode && displayDataReductionDialog) dataReductionDialog();

	nSeries = seriesNames.length;

	multichannelSeries = newArray(nSeries);
	multipositionSeries = newArray(nSeries);
	timeSeries = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		multichannelSeries = isMultiChannel(list, seriesNames[i]);
		multipositionSeries[i] = isMultiPosition(list, seriesNames[i]);
		timeSeries[i] = isTimeSeries(list, seriesNames[i]);
	}

	setBatchMode(true);
	roiImages = roiImageList(dir1+"ImagesWithRois");
	setBatchMode(false);
	if (crop && roiImages.length==0) {
		msg = "\nCrop at import but no images from which "+
			"get rois found in\n"+dir1+"ImagesWithRois"+
			"\nMetamorphFilesFolderToHyperstacks will exit.";
		print(msg);
		showMessage(msg);
		exit();
	}

	if (crop) {
		print("");
		prefixLessRoiImages = prefixLess(roiImages);
		seriesNames = reduceSeriesToRoiImages();
		print("After reduceSeriesToRoiImages()");
		for (i=0; i<seriesNames.length; i++)
			print ("seriesNames["+i+"] = "+seriesNames[i]);
		if (seriesNames.length<nSeries) {
			list = reduceList(list, seriesNames);
			nSeries = seriesNames.length;
		}
		print("Found "+nSeries+" series for which found images with rois:");
		for (i=0; i<seriesNames.length; i++)
			print ("seriesNames["+i+"] = "+seriesNames[i]);
		rebuildMultiCPTArrays(list);
	}

	doSeries = newArray(nSeries);
	for (i=0; i<nSeries; i++) doSeries[i] = true;
	//doSeries[0] = true;

	if (nSeries>1 && letMeChooseSeries) {
		displaySeriesNamesDialog();
	}

	if (nSeries>1)
		list = reduceListToSelectedSeries(list);
	nSeries = seriesNames.length;
	rebuildMultiCPTArrays(list);

	print("\nSelected series (seriesNames filtered by seriesNames):");
	for (i=0; i<seriesNames.length; i++) {
		print(seriesNames[i]);
		print("doSeries = "+doSeries[i]);
	}
	if (dbg) {
 		print("\nseries filtered filenames list:");
		for (i=0; i<list.length; i++) print(list[i]); print("");
	}
	seriesFilenamesStr = getSeriesFilenames(list);
	seriesChannelSequences = getSeriesChannelSequences();
	channelSequences = getChannelSequences(seriesChannelSequences);
	seriesWithSameChannels = groupSeriesHavingSameChannelSequence();
	print("");
	nSeries = seriesNames.length;

//	print("execute():");
	seriesFileNumbers = getSeriesFileNumbers(seriesFilenamesStr);
	print("");
	for (i=0; i<seriesFileNumbers.length; i++) {
		print("seriesFileNumbers["+i+"]="+seriesFileNumbers[i]);
	}
	print("\nTIFF and STK image list to be processed:");
	for (i=0; i<list.length; i++) print(list[i]);
	//getSeriesCalibrationOptions();
	atLeastOneTimeSeries = foundAtLeastOneTimeSeries();

	for (i=0; i<nSeries; i++) {
		//channelGroup index for each series, >= 0, < numberOfChannelGroups
		print("seriesChannelGroups["+i+"]="+seriesChannelGroups[i]);
	}
	channelGroupsHandlingDialog();
	channelColorsAndSaturationsDialog();

	filterExtensions = isExtensionFilter(fileFilter);
	//print("filterExtensions = "+filterExtensions);
	nSeries = seriesNames.length;
	print("Main code:");
	positionNumbers = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		//print("doSeries["+i+"]="+doSeries[i]);
		fnames = split(seriesFilenamesStr[i], _2DarraysSplitter);
		//n = getPositionsNumber(fnames, seriesNames[i]);//false return
		positionNumbers[i]=getPositionsNumber(fnames, seriesNames[i]);
		print("positionNumbers["+i+"]="+positionNumbers[i]);
	}
	findPositionsSeriesBySeries(list);

	if (crop) reducePositionsSeriesBySeries(prefixLessRoiImages);

	//for (i=0; i<positionsSeriesBySeries.length; i++)
	//	print("positionsSeriesBySeries["+i+"] = "+positionsSeriesBySeries[i]);

	print("");
	for (i=0; i<positionExists.length; i++)
		print("positionExists["+i+"]="+positionExists[i]);

	//for (i=0; i<isCompletePosition.length; i++)
	//	print("isCompletePosition["+i+"] = "+isCompletePosition[i]);//FALSE

	/* if crop, only series and positions for which an image with rois has
	been found in inputDir/ImagesWithRois are processed */

	positionsSeriesBySeriesDialog(list);//choose positions in selected series
	printParams();
	print("\nProcessing input folder selected series");
	if (crop) {
		print("\nlimited to rois from roiImages:");
		for (i=0; i<roiImages.length; i++)
			print("roiImages["+i+"]="+roiImages[i]);
		print("\nprefixLessRoiImages:");
		for (i=0; i<roiImages.length; i++)
			print("prefixLessRoiImages["+i+"]="+prefixLessRoiImages[i]);
		print("");
	}
	for (i=0; i<nSeries; i++)
		print(seriesNames[i]+"  timeSeries[i]="+timeSeries[i]);
	wasOpenMemory = isOpen("Memory");
	if (runMemoryMonitor) launchMemoryMonitor();
	else closeMemoryMonitor();
	startTime = getTime();
	delete_residual_Tmp_Log_files();
	if (crop && optimizeSpeed) processFolder2();
	else processFolder();
	if (wasOpenMemory) launchMemoryMonitor();
	else closeMemoryMonitor();

/*
Log saved recurently without extension or with a different name to workaround
bug on Win10 forbiding overwrite .txt files. Rename as ".txt" is authorized.
Fails if log name contains fileFilter.
path = dir2+"Log.txt";
if (File.exists(path)) File.delete(path);
File.rename(dir2+"Log", path);
*/
	finish();
}//execute()

function launchMemoryMonitor() {
	if (isOpen("Memory")) return;
	if (findFile(pluginsDir, "MemoryMonitor_Launcher.jar"))
		run("MemoryMonitor Launcher");
	else
		showMessage("Launch \"Monitor Memory...\" in a macro"+
			"\nrequires \"MemoryMonitor_Launcher.jar\""+
			"\nto be installed in plugins folder");
}

function closeMemoryMonitor() {
	if (!isOpen("Memory")) return;
	selectWindow("Memory");
	run("Close");
}

/** Returns array of elements of 'filenames' 
	starting with any element of 'seriesNames'
	seriesNames: array of image-series names */
function reduceList(filenames, seriesNames) {
	nF=filenames.length;
	nS=seriesNames.length;
	l=newArray(nF);
	n=0;
	for (i=0; i<nF; i++) {
		f=filenames[i];
		for (j=0; j<nS; j++)
			if (startsWith(f,seriesNames[j])) l[n++]=f;
	}
	return Array.trim(l,n);
}

/** Asks for each series if is to be processed or not
	Problem if more series than maximum number of checkboxes 
	that can be dispayed in a single dialog window */
function displaySeriesNamesDialog() {
	dbg=false;
	len=0;
	for (i=0; i<nSeries; i++) {
		len2=lengthOf(seriesNames[i]);
		if (len2>len) len=len2;
	}
	dialogBorderWidth = 10;//pixels
	charWidth = 8;//approximmative mean character width, pixels
	minimalCheckboxWidth = 22;//pixels
	maxCols = floor((screenWidth - 2 * dialogBorderWidth) /
		(len * charWidth + minimalCheckboxWidth));
	if (dbg) print("\ndisplaySeriesNamesDialog()");
	Dialog.create(macroName);
	Dialog.addMessage("Process series:");
	unavailableHeight = 144;//dialog height if no series to display
	checkboxHeight = 23;
	availableHeight = screenHeight-unavailableHeight;
	maxRows = floor(availableHeight/checkboxHeight)-1;
	columns = 1;
	if (nSeries<maxRows)
		for (i=0; i<nSeries; i++)
			Dialog.addCheckbox(seriesNames[i],true);
	else {
		rows = maxRows;
		columns = floor(nSeries/rows)+0;
		while (columns*rows<nSeries) columns++;
		while (columns*rows>nSeries+columns) rows--;
		//columns*rows must be >= nSeries
		if (dbg) {
			print("maxRows="+maxRows);
			print("rows="+rows);
			print("maxCols="+maxCols);
			print("columns="+columns);
			print("rows="+rows);
			print("nSeries="+nSeries);
			print("columns*rows="+columns*rows);
		}
		Dialog.addCheckboxGroup(rows, columns, seriesNames, doSeries);
	}
	if (columns>maxCols) {
		if (!getBoolean("Cannot display "+nSeries+
				" series names in dialog box"+
				"\nYes to process all series, No or Cancel to abort."))
			exit();
	}
	if (fullMode) Dialog.show();
	for (i=0; i<nSeries; i++)
		doSeries[i] = Dialog.getCheckbox();
	for (i=0; i<nSeries; i++)
		print("Series "+i+" "+seriesNames[i]+" doSeries="+doSeries[i]);
}

function getSeriesCompleteness() {//Not used
	print("\nnSeries="+nSeries);
	seriesCompleteness = newArray(nSeries);
	for (i=0; i<seriesFilenamesStr.length; i++) {
		//print("");
		seriesCompleteness[i]=true;
		fnames = seriesFilenamesStr[i];
		fnamesArray = split(fnames,"(/)");
		for (j=0; j<fnamesArray.length; j++) {
			//print("fnamesArray["+j+"]="+fnamesArray[j]);
			path = dir1+fnamesArray[j];
			if (!File.exists(path)) {
				seriesCompleteness[i]=false;
				//print("seriesCompleteness["+i+"] = "+seriesCompleteness[i]);
				break;
			}
		}
	}
}

/** Extracts MultiDimensional params from seriesName.nd excepted
	"NStagePositions" and names of positions "Stage1", "Stage2", etc. */
function getParamsFromND(seriesName) {
	print("\ngetParamsFromND("+seriesName+")");
	str = getNDContent(seriesName);
	if (str=="") {
		print("failed because could not getNDContent("+seriesName+")\n");
		return false;
	}
	if (!startsWith(str, "\"NDInfoFile\"")) return false;
	lines = split(str, "\n");
	if (lines.length==0) return false;
	//for (i=0; i<lines.length; i++) print("lines["+i+"] = "+lines[i]);
	for (i=0; i<lines.length; i++) {
		line = lines[i];
		if (startsWith(line, "\"NEvents\"")) break;
		if (startsWith(line, "\"DoTimelapse\""))
			if (indexOf(line, "TRUE") >= 0) DoTimelapse = true;
		if (startsWith(line, "\"NTimePoints\"")) {
			toks = split(line, ",");
			NTimePoints = parseInt(toks[1]);
		}
		if (startsWith(line, "\"DoStage"))
			if (indexOf(line, "TRUE") >= 0) DoStage = true;
		if (startsWith(line, "\"NStagePositions\"")) {
			toks = split(line, ",");
			NStagePositions = parseInt(toks[1]);
			i += NStagePositions;
		}
		line = lines[i];
		if (startsWith(line, "\"DoWave\""))
			if (indexOf(line, "TRUE") >= 0) DoWave = true;
		if (startsWith(line, "\"NWavelengths\"")) {
			toks = split(line, ",");
			NWavelengths = parseInt(toks[1]);
			WaveNames = newArray(NWavelengths);
			WaveDoZs = newArray(NWavelengths);
			for (w=1; w<=NWavelengths; w++) {
				line = lines[++i];
				//if (indexOf(line, "WaveName"+w)>=0) {
				if (startsWith(line, "\"WaveName"+w+"\"")) {
					toks = split(line, ",");
					WaveNames[w-1] = substring(toks[1],
						indexOf(toks[1], "\"")+1, lengthOf(toks[1])-1);
				}
				line = lines[++i];
				//if (indexOf(line, "WaveDoZ"+w)>=0) {
				if (startsWith(line, "\"WaveDoZ"+w+"\"")) {
					toks = split(line, ",");
					if (indexOf(toks[1], "TRUE")>=0) WaveDoZs[w-1] = true;
				}
			}
		}
		line = lines[i];
		if (startsWith(line, "\"DoZSeries\""))
			if (indexOf(line, "TRUE") >= 0) DoZSeries = true;
		if (!DoZSeries) NZSteps = 1;
		if (startsWith(line, "\"NZSteps\"")) {
			toks = split(line, ",");
			NZSteps = parseInt(toks[1]);
		}
		if (startsWith(line, "\"WaveInFileName\""))
			if (indexOf(line, "TRUE") >= 0) WaveInFileName = true;
	}
	print("DoTimelapse = "+DoTimelapse); //"DoTimelapse", TRUE
	print("NTimePoints = "+NTimePoints); //"NTimePoints", 3
	print("DoStage = "+DoStage); //"DoStage", TRUE
	print("NStagePositions = "+NStagePositions); //"NStagePositions", 2
	print("DoWave = "+DoWave); //"DoWave", TRUE
	print("NWavelengths = "+NWavelengths); //"NWavelengths", 2
	print("DoZSeries = "+DoZSeries); //"DoZSeries", TRUE
	print("NZSteps = "+NZSteps); //"NZSteps", 21
	print("WaveInFileName = "+WaveInFileName); //"WaveInFileName", TRUE
	for (i=0; i<WaveNames.length; i++)
		print("WaveNames["+i+"] = "+WaveNames[i]);
	for (i=0; i<WaveDoZs.length; i++)
		print("WaveDoZs["+i+"] = "+WaveDoZs[i]);
	print("");
	return true;
}//getParamsFromND(seriesName)

var imagesType, maxImageWidth, maxImageHeight, maxImageDepth;

//A REVOIR: utiliser seriesTimePoints (nb tpoints series[i]),
//nChannels[i], nPositions[i] (plutot minPosition[i] et maxPosition[i]
//ou positionsSeriesBySeries (plus complique)
/** Finds image type, maxWidth, maxHeight and maxDepth for series(seriesIndex).
	To be called in processFolder(), series loop */
function get_imagesType_maxWidth_maxHeight_maxDepth(seriesName) {
	print("\nget_imagesType_maxWidth_maxHeight_maxDepth("+seriesName+")");
	t0=getTime;
	dbg=false;
	seriesIdx = -1;
	for (i=0; i<seriesNames.length; i++)
		if (seriesNames[i]==seriesName) {seriesIdx=i; break;}
	if (seriesIdx==-1) {print("Cannot find series "+seriesName); return;}
	gotParamsFromND = getParamsFromND(seriesName);
	//maxImageDepth = NZSteps;
	if (dbg) print("\nseriesIndex = "+seriesIdx);
	wDependentBinning = false;
	mw = multichannelSeries[seriesIdx];//if wDependentBinning check nChannels
	mp = multipositionSeries[seriesIdx];//check 1 position
	ts = timeSeries[seriesIdx];//check 1 t-point: t1 if nFrames<2, t2 otherwise
	fnames = seriesFilenamesStr[seriesIdx];
	if (dbg) {print("Series "+seriesName); print("fnames = "+fnames);}
	fnamesArray = toArray(fnames, _2DarraysSplitter);
	print("fnamesArray.length = "+fnamesArray.length);
	allChannels = toArray(seriesChannelSequences[seriesIdx], _2DarraysSplitter);
	for (k=0; k<allChannels.length; k++) {
		if (allChannels[k]==0) allChannels[k]="";
		print("allChannels["+k+"] = "+allChannels[k]);
	}
	bitdepth = 16;
	wavesToCheck = 1;
	checkedWaves = 0;
	timePointsToCheck = 1;
	checkedTimePoints = 0;
	checkTimePoint2 = false;
	if (mw && wDependentBinning)
			wavesToCheck = allChannels.length;
	if (ts && nFrames>1) {
		timePointsToCheck = 1;//t1 & t2
		checkTimePoint2 = true;
	}
	maxW=0; maxH=0; maxD=0;
	for (j=0; j<fnamesArray.length; j++) {
		fname = fnamesArray[j];
		print("fnamesArray["+j+"]="+fname);
		path = dir1+fname;
		if (!File.exists(path)) continue;
		extensionlessName = substring(fname, 0, lastIndexOf(fname, "."));
		str = substring(extensionlessName, lengthOf(seriesName),
			lengthOf(extensionlessName));
		//print("str = "+str);
		if (startsWith(str, "_w")) {//MM doWave = true
			waveNumStr = substring(str, 2, 3);//less than 10 wavelengths
			waveNum = parseInt(waveNumStr);
			//print("checkedWaves = "+checkedWaves);
			//print("waveNum = "+waveNum);
			if (waveNum==checkedWaves) continue;
			checkedWaves = waveNum;
		}
		else {}
		id=0;
		use_tiff_tags_plugin = true;
		if (gotParamsFromND) {//fast
			print("Open first slice");
			open(path, 1);
			bitdepth=bitDepth();
			width=getWidth();
			height=getHeight();
			depth=NZSteps;
			print("gotParamsFromND:\nNZSteps="+NZSteps);
			close();
		}
		else if (getImageMetadata(path, id, !use_tiff_tags_plugin)) {//slow
			bitdepth = bitsPerPixel;
			width = pixelsX;
			height = pixelsY;
			depth = numberOfPlanes;
			print("numberOfPlanes="+numberOfPlanes);
		}
		else {//slow
			print("Open all slices");
			open(path);
			bitdepth=bitDepth();
			width=getWidth();
			height=getHeight();
			depth=nSlices();
			print("nSlices="+nSlices);
			close();
		}
		if (width>maxW) maxW=width;
		if (height>maxH) maxH=height;
		if (depth>maxD) maxD=depth;
		if (noChannelDependentBinning) break;
	}
	if (bitdepth==8) imagesType = "8-bit";
	else if (bitdepth==16) imagesType = "16-bit";
	else if (bitdepth==24) imagesType = "RGB";
	print("maxW="+maxW+" maxH="+maxH+" maxD="+maxD);
	maxImageWidth = maxW;
	maxImageHeight = maxH;
	maxImageDepth = maxD;
	print("imagesType="+imagesType);
	print("maxImageWidth="+maxImageWidth);
	print("maxImageHeight="+maxImageHeight);
	print("maxImageDepth="+maxImageDepth);
	print("get_imagesType_maxWidth_maxHeight_maxDepth("+seriesName+") done: "+
		(getTime()-t0)+"ms\n ");
/*
		//autre maniere de proceder (comme dans processFolder)
		nchn = 1;
		for (j=0; j<1; j++) {//positions
			for (t=1; t<=2; t++) {
				for (c=0; c<nchn; c++) {
					fname = seriesName + "";
				}
			}
		}
*/
}//get_imagesType_maxWidth_maxHeight_maxDepth()

function getSeriesCalibrationOptions() {//not used
	Dialog.create(macroName);
	s = "";
	for (i=0; i<seriesNames.length; i++) s += seriesNames[i] + "\n";
	Dialog.addMessage("Found following series in folder:\n"+s);
	Dialog.addChoice("Calibration option", calibrationOptions)
	//if (fullMode)
		Dialog.show();
	calibrationOption = Dialog.getChoice();
}

function dualCameraDialog() {
	machines = newArray(3);
	machines[0] = "Spinning Disk / Nikon - IGBMC";
	machines[1] = "Spinning Disk / Leica - IGBMC";
	machines[2] = "Other";
	Dialog.create(macroName);
	Dialog.addMessage("Dual Camera series:");
	Dialog.addChoice("Machine", machines);
	Dialog.addMessage("If input folder contains no Dual Camera series,"+
		"\nanswer is not used.");
	Dialog.addMessage("If Machine == Other,"+
		"\nyou may have to change first Checkbox and String"+
		"\nin next dialog.");
	Dialog.addMessage("N.B.:"+
		"\nIt's assumed that all dual channel series in input"+
		"\nfolder have been done using the same machine.");
	if (fullMode) Dialog.show();
	machine = Dialog.getChoice();
}

function dualCameraDialog2() {
	Dialog.create(macroName);
	firstDualChannelIllumSetting_is_w1 = true;
	if (machine=="Spinning Disk / Leica - IGBMC")
		firstDualChannelIllumSetting_is_w1 = false;
	dualChannelSeparator = "-";
	if (machine=="Spinning Disk / Nikon - IGBMC")
		dualChannelSeparator = "(\\s)";
	Dialog.addMessage("Dual Camera Series:");
	Dialog.addMessage("Example of wavelengths: _w1CSU491 561, _w2CSU491 561");
	Dialog.addCheckbox("First Illumination Setting is w1",
			firstDualChannelIllumSetting_is_w1);
	Dialog.addString("Illumination Settings Separator", dualChannelSeparator);
	Dialog.addToSameRow();
	Dialog.addMessage("parentheses = Regex");
	if (fullMode) Dialog.show();
	firstDualChannelIllumSetting_is_w1 = Dialog.getCheckbox();
	dualChannelSeparator = Dialog.getString();
}

function fileFilterAndCalibrationParamsDialog() {
	Dialog.create(macroName+"  -  Main Dialog");
	Dialog.addCheckbox("Display Memory", runMemoryMonitor);
	Dialog.addString("Process Filenames containing", fileFilter);
	Dialog.addString("Exclude Filenames  containing", excludingFilter);
	Dialog.addCheckbox("Filter files using .nd names", filterFilesWith_ndNames);
	Dialog.addCheckbox("No series have channel-dependent binning",
		noChannelDependentBinning);
	Dialog.addCheckbox("Display series choice dialog", letMeChooseSeries);
	msg = "Pixel-size from Metadata correction if badly declared objective:";
	Dialog.addMessage(msg);
	items = newArray("","0.5","1","1.25","1.6","2","2.5","4","5",
		"10","20","25","40","50","60","63","100","125","150");
	Dialog.addChoice("Real objective", items, "");
	Dialog.addChoice("Declared objective", items, "");
	Dialog.addMessage("Same correction will be applied to all series!");
	Dialog.addMessage("If no xy-z calibration found,"+
		" use following for all series:");
	Dialog.addNumber("Pixel size", 1);
	Dialog.addNumber("Z step", 0);
	Dialog.addChoice("Unit of length", XYZUnitChoices, XYZUnitChoices[0]);
	Dialog.addCheckbox("Use above XYZ-calibration for all series", false);
	Dialog.addCheckbox("z-projection by default for all series",
		doZprojsByDefault);
	Dialog.addCheckbox("Display Data Reduction Dialog",
		displayDataReductionDialog);
	Dialog.addCheckbox("MultiPosition series: position names from ND",
		positionNamesFromND);
//	if (atLeastOneTimeSeries) {
//		Dialog.addMessage("");
//		Dialog.addMessage("Time series:");
		Dialog.addMessage("If no frame interval or time unit found,"+
			" use this for all series:");
		Dialog.addNumber("Frame interval", 0);
		Dialog.addChoice("Time unit", TUnitChoices, TUnitChoices[1]);
		Dialog.addCheckbox("Use above time interval and unit for all series",
			useUserTimeCalibration);
		Dialog.addCheckbox("Ignore single timepoint channels",
			ignoreSingleTimepointChannels);
//	}
	Dialog.addMessage(author+"   boeglin@igbmc.fr");
	if (fullMode) Dialog.show();
	runMemoryMonitor = Dialog.getCheckbox();
	fileFilter = Dialog.getString();
	excludingFilter = Dialog.getString();
	filterFilesWith_ndNames = Dialog.getCheckbox();
	noChannelDependentBinning = Dialog.getCheckbox();
	letMeChooseSeries = Dialog.getCheckbox();
	realObjective = Dialog.getChoice();
	declaredObjective = Dialog.getChoice();
	userPixelSize = Dialog.getNumber();
	userVoxelDepth = Dialog.getNumber();
	userLengthUnit = Dialog.getChoice();
	useUserXYZCalibrations = Dialog.getCheckbox();
	doZprojsByDefault = Dialog.getCheckbox();
	displayDataReductionDialog = Dialog.getCheckbox();
	positionNamesFromND = Dialog.getCheckbox();
//	if (atLeastOneTimeSeries) {
		userFrameInterval = Dialog.getNumber();
		userTimeUnit = Dialog.getChoice();
		useUserTimeCalibration = Dialog.getCheckbox();
		ignoreSingleTimepointChannels = Dialog.getCheckbox();
//	}
	if (realObjective!="" && declaredObjective!="" &&
			realObjective!=declaredObjective) {
		doPixelSizeCorrection = true;
		pixelSizeCorrection = parseFloat(declaredObjective)/
			parseFloat(realObjective);
	}
}//fileFilterAndCalibrationParamsDialog()

function dataReductionDialog() {
	Dialog.create(macroName+" - Data Reduction");
	Dialog.addMessage("Data Reduction:");
	Dialog.addCheckbox("Resize at import", resize);
	Dialog.addNumber("Resize factor", resizeFactor);
	msg = "Crop at import:\n"+
		"Needs an   rois-image   for each series and position  to be\n"+
		"croped.\n"+
		"Rois are retrieved from images in  'ImagesWithRois'\n"+
		"subfolder of input folder.\n"+
		"If  'Crop at import'  is checked and no rois-images exist, the\n"+
		"macro aborts; \n"+
		"otherwise, only series and positions for which rois-images\n"+
		"are found are processed.\n"+
		"";
	Dialog.addMessage(msg);
	Dialog.addCheckbox("Extract Regions", crop);
	Dialog.addCheckbox("Help for Extract Regions", false);
	//cropChoices = newArray("None", "Optimize Speed", "Economise Memory");
	cropChoices = newArray("Optimize Speed", "Economise Memory");
	Dialog.addChoice("Crop at import:",
		cropChoices, cropChoices[0]);
	Dialog.addMessage("Z-series:");
	Dialog.addNumber("firstSlice", firstSlice, 0, 4,
			"-1 for nSlices whatever stackSize");
	Dialog.addNumber("lastSlice", lastSlice, 0, 4,
			"-1 for nSlices whatever stackSize");
	Dialog.addCheckbox("Process range around median slice",
			doRangeAroundMedianSlice);
	Dialog.addNumber("Range", rangeAroundMedianSlice, 0, 4,
			"% of stackSize; <0: reverse stack");
	Dialog.addMessage("Multi-position series:");
	Dialog.addNumber("firstPosition", firstPosition, 0, 4,
			"");
	Dialog.addNumber("lastPosition", lastPosition, 0, 4,
			"-1 means last found position");
	Dialog.addMessage("Time-series:");
	Dialog.addNumber("firstTimePoint", firstTimePoint, 0, 4,
			"");
	Dialog.addNumber("lastTimePoint", lastTimePoint, 0, 4,
			"-1 means last found time point");
	Dialog.addCheckbox("Process range from t1", doRangeFrom_t1);
	Dialog.addNumber("Range", rangeFrom_t1, 0, 4,
			"% of timelapse duration");
	if (fullMode) Dialog.show();
	resize = Dialog.getCheckbox();
	resizeFactor = Dialog.getNumber();
	if (!resize) resizeFactor = 1;
	if (resizeFactor==0) resizeFactor = 1;
	if (resizeFactor!=1) {
		userPixelSize /= resizeFactor;
	}
	crop = Dialog.getCheckbox();
	//print("dataReductionDialog(): crop = "+crop);
	if (crop) File.makeDirectory(dir1+"ImagesWithRois");
	msg1 = "Any rois-image in  ImagesWithRois  folder must be a copy\n"+
		"of an iput image of the series or position to be croped.\n \n"+
		"It can also be a projection of any type of any input image.\n"+
		"The prefix 'MAX_' or 'MIN_' etc needs not to be removed.\n \n"+
		"To add rois to the overlay of an image: \n"+
		"  - draw an roi, type Ctrl b\n"+
		"  - change its location or draw another one, type Ctrl b\n"+
		"  - repeat until all crop-regions are done for the series or\n"+
		"    position\n"+
		"Do this for 1 image of each series or position to be croped.\n \n"+
		"Multichannel series:\nrois-image can be any channel.\n \n"+
		"Time series:\nrois-image can be any timepoint.\n \n"+
		"Whatever series type:\nat most 1 rois-image per series or position."+
		"";
	msg2 = "\n \nProcess options:";
	msg3 = "\n \nOptimize Speed:\nOutput images  of  extracted  regions "+
		"of  current series or \nposition occupy memory simultaneously. "+
		"\nEnsure  the  sum  of  output image sizes   doesn't  exceed\n"+
		"ImageJ's memory for any of the series and positions to be\nprocessed.";
	msg4 = "\n \nEconomise Memory:\nSeries or position process-time is"+
		" proportional to number \nof extracted regions from given"+
		" series or position.";
	if (Dialog.getCheckbox())
		showMessage("Extract Regions", msg1+msg2+msg3+msg4);
	choice = Dialog.getChoice();
	optimizeSpeed = (choice==cropChoices[0]);
	firstSlice = Dialog.getNumber();
	lastSlice = Dialog.getNumber();
	doRangeAroundMedianSlice = Dialog.getCheckbox();
	rangeAroundMedianSlice = Dialog.getNumber();// % of nSlices
	firstPosition = Dialog.getNumber();
	lastPosition = Dialog.getNumber();
	firstTimePoint = Dialog.getNumber();
	lastTimePoint = Dialog.getNumber();
	doRangeFrom_t1 = Dialog.getCheckbox();
	rangeFrom_t1 = Dialog.getNumber();
}

/* Display may be incomplete if many channel groups with many channels */
function channelGroupsHandlingDialog() {
	dbg = false;
	doChannelsFromSequences = newArray(seriesWithSameChannels.length);
	doZprojForChannelSequences = newArray(seriesWithSameChannels.length);
	projTypesForChannelSequences = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName+"  -  Channels handling");
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	seriesnames = toArray(seriesWithSameChannels[i], _2DarraysSplitter);
		if (i>0) Dialog.addMessage("");
		Dialog.addChoice("Channel group "+i+" contains", seriesnames);
		Dialog.addToSameRow();
	 	Dialog.addCheckbox("Do Z-projections", doZprojsByDefault);
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, _2DarraysSplitter);
	 	defaults = newArray(chns.length);
	 	for (j=0; j<chns.length; j++) {
	 		if (chns[j]==0) chns[j] = "Unknown Illumination";
	 		defaults[j] = true;
	 	}
	 	Dialog.addCheckboxGroup(1, chns.length, chns, defaults);
	 	makeColorsDifferent = false;
	 	chnColors = getChannelColors(chns, makeColorsDifferent);
		channelsSeqProjTypes = initProjTypes(chns, chnColors);
		for (j=0; j<chns.length; j++)
			Dialog.addChoice(chns[j], projectionTypes, channelsSeqProjTypes[j]);
	}
	if (fullMode) Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, _2DarraysSplitter);
	 	doChnStr = "";
	 	doZprojForChannelSequences[i] = Dialog.getCheckbox();
	 	for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getCheckbox();
	 		doChnStr = doChnStr + str + _2DarraysSplitter;
	 	}
	 	doChnStr = substring(doChnStr, 0, lengthOf(doChnStr)-1);
	 	doChannelsFromSequences[i] = doChnStr;
	 	projTypesStr = "";
		for (j=0; j<chns.length; j++)
			projTypesStr = projTypesStr+Dialog.getChoice()+_2DarraysSplitter;
		projTypesStr = substring(projTypesStr, 0, lengthOf(projTypesStr)-1);
		projTypesForChannelSequences[i] = projTypesStr;
	}
	if (dbg)
		for (i=0; i<doChannelsFromSequences.length; i++) {
			print("\nSeries: "+seriesnames[i]);
			print("doChannelsFromSequences["+i+"]="+doChannelsFromSequences[i]);
			print("doZprojForChannelSequences["+i+"]="+
				doZprojForChannelSequences[i]);
			print("projTypesForChannelSequences["+i+"]="+
				projTypesForChannelSequences[i]);
		}
}

/* Display may be incomplete if many channel groups with many channels */
function channelColorsAndSaturationsDialog() {
	dbg = false;
	channelSequencesColors = newArray(seriesWithSameChannels.length);
	channelSequencesSaturations = newArray(seriesWithSameChannels.length);
	Dialog.create(macroName+"  -  Channel colors and saturations");
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	if (i>0) Dialog.addMessage("");
	 	seriesnames = toArray(seriesWithSameChannels[i], _2DarraysSplitter);
		Dialog.addChoice("Channel group "+i+"", seriesnames);
		Dialog.addToSameRow();
		Dialog.addMessage("(for information)");
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, _2DarraysSplitter);
		channelColorIndexes = initChannelColorIndexes(chns);
	 	//makeColorsDifferent = true;
		//if (ensureColorsAreDifferent)
		//	idx = ensureColorIndexesAreDifferent(idx);
		for (j=0; j<chns.length; j++) {
			defaultClr = compositeColors[channelColorIndexes[j]];
			if (chns[j]==0) {
				chns[j] = "Unknown Illumination";
				defaultClr = compositeColors[3];
			}
			Dialog.addChoice(chns[j], compositeColors, defaultClr);
			//channelColorIndexes a refaire pour channelSequences
			Dialog.addToSameRow() ;
			Dialog.addNumber("", 0.01, 2, 5, "% saturated pixels");
		}
	}
	if (fullMode) Dialog.show();
	for (i=0; i<seriesWithSameChannels.length; i++) {
		unusedVariable = Dialog.getChoice();
	 	channelSeq = channelSequences[i];
	 	chns = toArray(channelSeq, _2DarraysSplitter);
	 	clrs = "";
		saturations = "";
		for (j=0; j<chns.length; j++) {
	 		str = "" + Dialog.getChoice();
	 		clrs = clrs + str + _2DarraysSplitter;
	 		saturations = saturations + Dialog.getNumber() + _2DarraysSplitter;
	 	}
	 	clrs = substring(clrs, 0, lengthOf(clrs)-1);
	 	channelSequencesColors[i] = clrs;
		saturations = substring(saturations, 0, lengthOf(saturations)-1);
		channelSequencesSaturations[i] = saturations;
	}
	for (i=0; i<doChannelsFromSequences.length; i++) {//verification
		seriesnames = toArray(seriesWithSameChannels[i], _2DarraysSplitter);
		if (dbg) print("\nSeries :"+seriesNames[i]+":");
		if (dbg)
			print("channelSequencesColors["+i+"] = "+channelSequencesColors[i]);
		if (dbg) print("channelSequencesSaturations["+i+"] = "+
				channelSequencesSaturations[i]);
	}
}

function initChannelSaturations(channelSeqs) {//Not used (complicated)
	channelSeqsSaturations = newArray(seriesWithSameChannels.length);
	for (i=0; i<seriesWithSameChannels.length; i++) {
	 	channelSeq = channelSeqs[i];
	 	chns = toArray(channelSeq, _2DarraysSplitter);
	 	str = "";
	 	for (j=0; j<chns.length; j++) {str += 0.01+_2DarraysSplitter;}
	 	str = substring(str, 0, lengthOf(str)-2);
	 	channelSeqsSaturations[i] = str;
	}
	return channelSeqsSaturations;
}

/** Requires folder has been analyzed, series built etc.
	position exists means not it's complete, some files may be missing. */
function findPositionsSeriesBySeries(filenames) {
	dbg = true;
	dbg2 = false;
	//les series ayant une seule position sont marquees par "" 
	//dans positionsSeriesBySeries et userPositionsSeriesBySeries.
	//les positions inexistantes ou non retenues sont marquees par 0
	arraysLength = 0;//at least equal to maxPosition
	nSeries = seriesNames.length;
	for (i=0; i<nSeries; i++) {
		print("positionNumbers["+i+"] = "+positionNumbers[i]);
	}
	if (dbg)
		print("\n \nfindPositionsSeriesBySeries(filenames): nSeries="+nSeries);
	for (i=0; i<nSeries; i++) {
		n = positionNumbers[i];
		arraysLength += n;
	}
	if (dbg) {
		print("Max position number: n = "+arraysLength);
		print("maxPosition = "+maxPosition);//wrong (0)
	}
	positionsSeriesBySeries = newArray(arraysLength);
	positionExists = newArray(arraysLength);
	isCompletePosition = newArray(arraysLength);
	userPositionsSeriesBySeries = newArray(arraysLength);
	index = -1;
	for (k=0; k<nSeries; k++) {
		fnames = split(seriesFilenamesStr[k], _2DarraysSplitter);
		print("seriesNames["+k+"] = "+seriesNames[k]+" :");
		seriesName = seriesNames[k];
		seriesName = toRegex(seriesName);
		npositions = positionNumbers[k];
		mp = multipositionSeries[k];
		mw = isMultiChannel(filenames, seriesNames[k]);
		ts = isTimeSeries(filenames, seriesNames[k]);
		waveRegex = ".*";
		if (mw) waveRegex = "_w\\d.*";
		if (mp) {
			startPosition = firstPosition;
			if (startPosition<1) startPosition = 1;
			stopPosition = lastPosition;
			if (stopPosition==-1) stopPosition = npositions;
			if (stopPosition>npositions) stopPosition = npositions;
			print("Process positions from _s"+
				startPosition+" to _s"+stopPosition);
			for (i=startPosition-1; i<stopPosition; i++) {
				iPlus1 = i+1;
				pExists = false;
				str = "_s"+iPlus1;
				if (ts) str += "_";
				else str += "\\.";
				if (dbg) print("str = "+str);
				for (j=0; j<fnames.length; j++) {
					seriesNameLessName = substring(fnames[j],
					lengthOf(seriesNames[k]), lengthOf(fnames[j]));
					if (dbg2) {
						print("seriesNameLessName = "+seriesNameLessName);
						print("fnames["+j+"] = "+fnames[j]);
					}
					fname = fnames[j];
					fname = toRegex(fname);
/*
					if (isPositionFilter(fileFilter)) {
						if (endsWith(fileFilter, "_")) str += "_";
						else if (endsWith(fileFilter, ".")) str += "\\.";
					}
*/
					//print("fname = "+fname);
					//if (dbg) print("str = "+str);
					//if (dbg) print("waveRegex = "+waveRegex);
					if (matches(seriesNameLessName, waveRegex+str+".*")) {
						pExists = true;
						positionsSeriesBySeries[++index] = "_s"+iPlus1;
						positionExists[index] = true;
						break;
					}
				}
				if (dbg) print("pExists = "+pExists);
				if (!pExists) index++;
			}
		}
		else {
			positionsSeriesBySeries[++index] = "";
			positionExists[index] = true;
		}
	}
	for (i=0; i<positionsSeriesBySeries.length; i++) {
		print("positionsSeriesBySeries["+i+"] = "+positionsSeriesBySeries[i]);
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
		print("positionNumbers["+k+"] = "+npositions);
		mp = multipositionSeries[k];
		ts = timeSeries[k];
		nFrames = getFramesNumber(filenames, seriesNames[k]);
		mw = isMultiChannel(filenames, seriesNames[k]);
		channels = getChannelNames(filenames, seriesNames[k]);
		nChn = 1;
		if (mw) nChn = channels.length;
		expectedFileNumber = nFrames * nChn * nPositions;
		print("Series "+k+" expectedFileNumber = "+expectedFileNumber);
		extensionsRegex = "TIF|tif|TIFF|tiff|STK|stk";
		index = -1;
		if (mp) {
			//if (dbg) print("npositions = "+npositions);
			for (i=0; i<npositions; i++) {
				if (!positionExists[i]) {index++; continue;}
				fileNumber = 0;
				iPlus1 = i+1;
				filenameRegex = seriesNames[k];
				filenameRegex = toRegex(filenameRegex);
				//if (dbg) print("filenameRegex = "+filenameRegex);
				if (mw) filenameRegex = filenameRegex+"_w\\d";
				filenameRegex = filenameRegex+"_s"+iPlus1;
				//if (dbg) print("filenameRegex = "+filenameRegex);
				if (ts) filenameRegex = filenameRegex+"_t\\d*";
				//if (dbg) print("filenameRegex = "+filenameRegex);
				filenameRegex = filenameRegex+"\\."+extensionsRegex;
				if (dbg) print("filenameRegex = "+filenameRegex);
				for (j=0; j<fnames.length; j++) {
					if (matches(fnames[j], filenameRegex)) fileNumber++;
				}
				if (fileNumber==expectedFileNumber) {//peut pas marcher
					isCompletePosition[++index] = true;
					userPositionsSeriesBySeries[index] = "_s"+iPlus1;
				}
			}
		}
		else {
			fileNumber = 0;
			filenameRegex = seriesNames[k];
			filenameRegex = toRegex(filenameRegex);//ok
			if (mw) filenameRegex = filenameRegex+"_w\\d";
			if (ts) filenameRegex = filenameRegex+"_t\\d*";
			filenameRegex = filenameRegex+"\\."+extensionsRegex;
			for (j=0; j<fnames.length; j++)
				if (matches(fnames[j], filenameRegex)) fileNumber++;
			if (fileNumber==expectedFileNumber) {
				isCompletePosition[++index] = true;
				userPositionsSeriesBySeries[index] = "";
			}
		}
	}
	for (i=0; i<positionsSeriesBySeries.length; i++)
		userPositionsSeriesBySeries[i] = positionsSeriesBySeries[i];
	if (dbg) print("\nEnd findPositionsSeriesBySeries(filenames):");
	print("");
	for (i=0; i<positionsSeriesBySeries.length; i++)
		print("positionsSeriesBySeries["+i+"] = "+positionsSeriesBySeries[i]);
}//findPositionsSeriesBySeries()

function prefixLess(roiImages) {
	n = roiImages.length;
	list2 = newArray(n);
	for (i=0; i<n; i++) {
		s = roiImages[i];
		for (j=0; j<projPrefixes.length; j++) {
			prefix  = projPrefixes[j];
			if (startsWith(s, prefix)) {
				list2[i] = substring(s, lengthOf(prefix), lengthOf(s));
				break;
			}
		}
	}
	return list2;
}

/** Adds ROIs from roiImage corresponding to current series and position
	to ROI Manager.
	roiImages: list of filnames in folder dir1+"ImagesWithRois"
	seriesName: name of currently processed series
	channels: array of current series channel-strings. channel-string may be ""
	position: name of currently processed position: "_s1", "_s2", etc
	In case of several images with rois matching a given series or position
	the used one is first in the 'prefixLessRoiImages' list */
function getRoisFromImage(prefixLessRoiImages, seriesName, channels, position) {
	print("getRoisFromImage(roiImages, "+seriesName+
			", channels, position = "+position+")");
	print("seriesName: "+seriesName);
	print("position = "+position);
	roiManager("reset");
	for (i=0; i<prefixLessRoiImages.length; i++) {
		prefixLessRoiImage = prefixLessRoiImages[i];
		if (!startsWith(prefixLessRoiImage, seriesName)) continue;
		if (indexOf(prefixLessRoiImage, position)<0) continue;
		pos = getPositionString(prefixLessRoiImage);
		if (pos!=position) continue;
		seriesLessName = substring(prefixLessRoiImage, lengthOf(seriesName), 
				lengthOf(prefixLessRoiImage));
		for (j=0; j<channels.length; j++) {
			print("channels["+j+"] = "+channels[j]);
			channel = channels[j];
			if (channel!="" && !startsWith(seriesLessName, channel))
				continue;
			channelLessName = substring(seriesLessName, lengthOf(channel),
					lengthOf(seriesLessName));
			if (startsWith(channelLessName, position)) {
				print("getting rois from\n"+roiImages[i]+"\n ");
				open(dir1+"ImagesWithRois"+File.separator+roiImages[i]);
				run("To ROI Manager");
				close();
				return true;
			}
		}
	}
	return false;
}

function getPositionString(fileName) {
	if (matches(fileName, ".*_s\\d{1,3}.*")) {
		str = substring(fileName, lastIndexOf(fileName, "_s"));
		//print("str = "+str);
		if (indexOf(str, ".")>=0)
			str = substring(str, 0, lastIndexOf(str, "."));
		//print("str = "+str);
		if (matches(str, ".*_t\\d{1,5}.*"))
			return substring(str, 0, lastIndexOf(str, "_t"));
	}
	return "";
}


/* Called after reduceSeriesToRoiImages() */
function rebuildMultiCPTArrays(filenames) {
	nSeries = seriesNames.length;
	multichannelSeries = newArray(nSeries);
	multipositionSeries = newArray(nSeries);
	timeSeries = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		multichannelSeries[i] = isMultiChannel(filenames, seriesNames[i]);
		multipositionSeries[i] = isMultiPosition(filenames, seriesNames[i]);
		timeSeries[i] = isTimeSeries(filenames, seriesNames[i]);
	}
}

function reduceSeriesToRoiImages() {
	print("\n\nreduceSeriesToRoiImages()");
	nSeries = seriesNames.length;
	seriesNames2 = newArray(nSeries);
	n2 = 0;
	for (j=0; j<nSeries; j++) {
		seriesName = seriesNames[j];
		for (i=0; i<roiImages.length; i++) {
			prefixLessName = prefixLessRoiImages[i];
			print("prefixLessName = "+prefixLessName);
			if (!startsWith(prefixLessName, seriesName)) continue;
			if (belongsToSeries(prefixLessName, seriesName)) {
				seriesNames2[n2++] = seriesName;
				break;
			}
		}
	}
	//print("nSeries2 = "+n2);
	return Array.trim(seriesNames2, n2);
}

function belongsToSeries(prefixLessRoiImageName, seriesName) {
	seriesLessName = substring(prefixLessRoiImageName, lengthOf(seriesName), 
			lengthOf(prefixLessRoiImageName));
	print("seriesLessName = "+seriesLessName);
	if (startsWith(seriesLessName, "_w")) return true;
	if (startsWith(seriesLessName, "_s")) return true;
	if (startsWith(seriesLessName, "_t")) return true;
	if (startsWith(toLowerCase(seriesLessName), ".tif")) return true;
	if (startsWith(toLowerCase(seriesLessName), ".stk")) return true;
	return false;
}

/* Returns array of TIF and STK imagenames in imagesWithRoisDir */
function roiImageList(imagesWithRoisDir) {
	l = getFileList(imagesWithRoisDir);
	nf = l.length;
	l2 = newArray(nf);
	n = 0;
	for (i=0; i<nf; i++) {
		f = l[i];
		if (File.isDirectory(f)) continue;
		if (!endsWith(toUpperCase(f), ".TIF") &&
			!endsWith(toUpperCase(f), ".STK")) continue;
		open(imagesWithRoisDir+File.separator+f);
		nr = Overlay.size;
		close();
		if (nr<1) continue;
		l2[n++] = f;
	}
	return Array.trim(l2, n);
}

/** Recalculates arrays needed for positions and rois processing of all series
	prefixLessRoiImages: RoiImageNames without AVG_, MAX_, MIN_, ... prefixes
	recalculates also positionNumbers[i] for series i, i=0, nSeries */
function reducePositionsSeriesBySeries(prefixLessRoiImages) {
	print("");
	print("Before reducePositionsSeriesBySeries(prefixLessRoiImages)");
	for (i=0; i<nSeries; i++)
		print("positionNumbers["+i+"] = "+positionNumbers[i]);
	//positionsSeriesBySeries: 1D array listing sequentially positions of
	//all series; its use needs number of positions for each series
	totalPositions = positionsSeriesBySeries.length;//old total positions number
	print("totalPositions = "+totalPositions);
	print("");
	positionsSeriesBySeriesNew = newArray(totalPositions);
	positionExistsNew = newArray(totalPositions);
	isCompletePositionNew = newArray(totalPositions);
	nSeries = seriesNames.length;
	print("nSeries = seriesNames.length = "+nSeries);
	positionNumbersNew = newArray(nSeries);
	q=0; r=0;
	for (i=0; i<nSeries; i++) {
		seriesName = seriesNames[i];
		for (j=0; j<positionNumbers[i]; j++) {
			position = positionsSeriesBySeries[r];//"_s1", "_s2" etc
			for (k=0; k<prefixLessRoiImages.length; k++) {
				s = prefixLessRoiImages[k];
				if (!startsWith(s, seriesName)) continue;
				//remove seriesName:
				s = substring(s, lengthOf(seriesName), lengthOf(s));
				//print("s = "+s); print("position = "+position);
				//time series: _ or not: \\.
				if (matches(s,".*"+position+"[_\\.]"+".*")) {
					positionNumbersNew[i]++;
					positionsSeriesBySeriesNew[q] = position;
					positionExistsNew[q] = positionExists[r];
					isCompletePositionNew[q] = isCompletePositionNew[r];
					q++;
					break;
				}
			}
			r++;
		}
	}
	positionNumbers = positionNumbersNew;
	for (i=0; i<nSeries; i++)
		print("positionNumbers["+i+"] = "+positionNumbers[i]);
	positionsSeriesBySeriesNew = Array.trim(positionsSeriesBySeriesNew, q);
	positionExistsNew = Array.trim(positionExistsNew, q);
	isCompletePositionNew = Array.trim(isCompletePositionNew, q);
	positionsSeriesBySeries = positionsSeriesBySeriesNew;
	positionExists = positionExistsNew;
	isCompletePosition = isCompletePositionNew;
	userPositionsSeriesBySeries = Array.copy(positionsSeriesBySeries);
	for (i=0; i<positionsSeriesBySeries.length; i++)
		print("positionsSeriesBySeries["+i+"] = "+positionsSeriesBySeries[i]);
}

//AFFICHE LES POSITIONS SUR DES LIGNES HORIZONTALES DANS PLUSIEURS DIALOGUES
//SI NECESSAIRE POUR LIMITER LEUR HAUTEUR A CELLE DE L'ECRAN
function positionsSeriesBySeriesDialog(filenames) {
	dbg = false;
	print("positionsSeriesBySeriesDialog: seriesNames.length = "
			+seriesNames.length);
	multiposSeries = 0;
	for (k=0; k<seriesNames.length; k++) {
		n = positionNumbers[k];
		print("positionNumbers["+k+"] = "+positionNumbers[k]);
		//print("seriesNames["+k+"] = "+seriesNames[k]);
		if (doSeries[k] && n>1) {
			multiposSeries++;
		}
	}
	print("multiposSeries = "+multiposSeries);
	if (multiposSeries==0) return;
	//3 series / h = 198 --o-> 1 serie pour h = 66;
	//soustraire 140 pour la fenetre, le message et le bouton OK
	nWindows = 1+floor(multiposSeries * 66 / (screenHeight() - 140));
	if (nWindows==0) nWindows = 1;
	seriesPerWindow = floor(multiposSeries / nWindows);
	seriesInLastWindow = multiposSeries % nWindows;
	if (seriesInLastWindow==0) seriesInLastWindow = seriesPerWindow;
	if (dbg) {
		print("nWindows = "+nWindows);
		print("seriesPerWindow = "+seriesPerWindow);
		print("seriesInLastWindow = "+seriesInLastWindow);
	}
	//Create dialogs
	index = 0;
	seriesIndex = 0;
	for (k=0; k<seriesNames.length; k++) {
		//ESSAI DESACTIVATION
		//if (doSeries[k] && positionNumbers[k]>1) break;
		//ESSAI
		if (doSeries[k]) break;

		//ESSAI DESACTIVATION
		//if (!doSeries[k] || positionNumbers[k]<2) {
		//ESSAI
		if (!doSeries[k]) {
			seriesIndex++;
			index += positionNumbers[k];
		}
	}
	index0 = index;
	//index0 = numero 1ere position de positionsSeriesBySeries a traiter
	if (dbg) print("index0 = "+index0);
	//seriesIndex0 = numero 1ere serie a taiter
	seriesIndex0 = seriesIndex;
	if (dbg) print("seriesIndex0 = "+seriesIndex0);
	for (w=0; w<nWindows; w++) {
		Dialog.create(macroName);
		Dialog.addMessage("Choose positions to process:");
		lines = 0;//nb de series ajoutees aux dialogues
		k = seriesIndex0;
		while (lines < seriesPerWindow) {
		//for (k=seriesIndex; k<seriesIndex+seriesPerWindow; k++) {
			if (k==seriesNames.length) break;
			n = positionNumbers[k];
	//		print("seriesNames["+k+"] = "+seriesNames[k]);
			
			if (doSeries[k]) {//ESSAI
			//if (doSeries[k] && n>1) {ESSAI
				lines++;
				Dialog.addMessage(seriesNames[k]+":");
				if (dbg) print("n = "+n);
				n2 = 0;
				//n2 : nb de positions reellement presentes, different de n
				for (i=index; i<index+n; i++) {
					//print("index = "+index);
					//print("i = "+i);
					//positionOK = positionExists[i] && isCompletePosition[i];
					//positionOK = positionExists[i];//isCompletePosition: pb
					if (i==positionsSeriesBySeries.length) break;
					//if (positionsSeriesBySeries[i]=="0") continue;
					if (positionsSeriesBySeries[i]=="") continue;//ESSAI
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
		if (fullMode) Dialog.show();

		for (i=0; i<positionsSeriesBySeries.length; i++) {
			userPositionsSeriesBySeries[i] = positionsSeriesBySeries[i];
		}
		//Answer dialog
		index = index0;
		seriesIndex = seriesIndex0;
		lines = 0;
		k = seriesIndex0;
		//print("seriesIndex0 = "+seriesIndex0);
		while (lines < seriesPerWindow) {
			//print("seriesNames["+k+"] = "+seriesNames[k]);
			//print("k = "+k);
			//print("index = "+index);
			if (k==seriesNames.length) break;
			n = positionNumbers[k];
			//index += n;
			if (doSeries[k]) {//ESSAI
			//if (doSeries[k] && n>1) {//ESSAI
				lines++;
				//print("answer dialog : i = "+i);
				for (i=index; i<index+n; i++) {
					if (i==positionsSeriesBySeries.length) break;
					//positionOK = positionExists[i] && isCompletePosition[i];
					positionOK = positionExists[i];//isCompletePosition:problem
					if (positionOK) {
						if (!doSeries[k]) {
							userPositionsSeriesBySeries[i] = false;
						}
						else {
							if (positionsSeriesBySeries[i]=="") continue;
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
	//print("Answer dialog: ");
	for (i=0; i<userPositionsSeriesBySeries.length; i++) {
		print("userPositionsSeriesBySeries["+i+"] = "
				+userPositionsSeriesBySeries[i]);
	}
}//positionsSeriesBySeriesDialog()

function printParams() {
	print("\nParameters:");
	print("Input dir: "+dir1);
	print("Ouput dir: "+dir2);
	print("runMemoryMonitor = "+runMemoryMonitor);
	print("fileFilter = "+"\""+fileFilter+"\"");
	print("excludingFilter = "+"\""+excludingFilter+"\"");
	print("filterFilesWith_ndNames = "+"\""+filterFilesWith_ndNames+"\"");
	print("realObjective = "+realObjective);
	print("declaredObjective = "+declaredObjective);
	print("doPixelSizeCorrection = "+doPixelSizeCorrection);
	print("pixelSizeCorrection = "+pixelSizeCorrection);
	print("userPixelSize = "+userPixelSize);
	print("userVoxelDepth = "+userVoxelDepth);
	print("userLengthUnit = "+userLengthUnit);
	print("useUserTimeCalibration = "+useUserTimeCalibration);
	print("userFrameInterval = "+userFrameInterval);
	print("userTimeUnit = "+userTimeUnit);
	print("crop = "+crop);
	print("optimizeSpeed = "+optimizeSpeed);
	print("resize = "+resize);
	print("resizeFactor = "+resizeFactor);
	print("firstSlice = "+firstSlice);
	print("lastSlice = "+lastSlice);
	print("firstTimePoint = "+firstTimePoint);
	print("lastTimePoint = "+lastTimePoint);
	print("doRangeFrom_t1 = "+doRangeFrom_t1);
	print("rangeFrom_t1 = "+rangeFrom_t1);
	print("positionNamesFromND = "+positionNamesFromND);
	print("End of Parameters");
}

function foundAtLeastOneTimeSeries() {
	for (i=0; i<seriesNames.length; i++)
		if (timeSeries[i]) return true;
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
		skip = false;
		for (k=0; k<projPrefixes.length; k++)
			if (startsWith(s, projPrefixes[k])) {
				skip = true;
				break;
			}
		if (skip) continue;
		list2[j++] = s;
	}
	if (j<1) {
		showMessage(macroName,"Input folder:\n"+dir+
			"\nseems not to contain Metamorph images to merge");
		exit();
	}
	for (i=0; i<list2.length; i++) {
		list2[i] = toString(list2[i]);
	}
	list2 = Array.trim(list2, j);
	list2 = Array.sort(list2);
	return list2;
}

/** Returns TIFF and STK files contained in 'list' matching fileFilter and 
	not matching excludingFilter */
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
		list2[j++] = s;
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

/** Removes singlets (files constituting series by themself, for instance
	output files of this macro) from list. 
	Called after filterList(list, fileFilter, excludingFilter) */
function removeSinglets(list) {
	list2 = newArray(list.length);
	j = 0; k = 0;
	for (i=0; i<list.length; i++) {
		fname = list[i];
		if (indexOf(fname, ".") < 1) continue;
		fname = substring(fname, 0, lastIndexOf(fname, "."));
		if (!matches(fname, ".*_t\\d+") && !matches(fname, ".*_w\\d+.*" )) {
			if (k++==0)
				print("\nSinglets or Non Metamorph-acquired-unprocessed"+
						" files, excluded from processing:");
			print(list[i]);
			continue;
		}
		list2[j++] = list[i];
	}
	return Array.trim(list2, j);
}

/** Returns filenames 'list' reduced to selected series.
	To be called after choice of series;
	then, doSeries & seriesNames must be restricted to selected series */
function reduceListToSelectedSeries(list) {
	doAll = true;
	keptSeries = 0;
	for (i=0; i<doSeries.length; i++) {
		if (doSeries[i])
			keptSeries++;
		else
			doAll = false;
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
	j=0;
	for (i=0; i<doSeries.length; i++) {
		if (doSeries[i]) {
			doSeriesFiltered[j] = true;
			seriesNamesFiltered[j++] = seriesNames[i];
		}
	}
	list2 = newArray(list.length);
	k=0;
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

function initXYCalibrations(seriesNames) {
	XYCalibrations = newArray(seriesNames.length);
	for (i=0; i<seriesNames.length; i++) XYCalibrations[i] = 1;
	return XYCalibrations;
}

function initZCalibrations(seriesNames) {
	ZCalibrations = newArray(seriesNames.length);
	for (i=0; i<seriesNames.length; i++) ZCalibrations[i] = 0;
	return ZCalibrations;
}

function initXYZUnits(seriesNames) {
	XYZUnits = newArray(seriesNames.length);
	for (i=0; i<seriesNames.length; i++) XYZUnits = XYZUnitChoices[0];//"pixel"
	return XYZUnits;
}

function initTimeIntervals(seriesNames) {
	TimeIntervals = newArray(seriesNames.length);
	for (i=0; i<seriesNames.length; i++) TimeIntervals[i] = 0;
	return TimeIntervals;
}

function initTUnits(seriesNames) {
	TUnits = newArray(seriesNames.length);
	for (i=0; i<seriesNames.length; i++)
		TUnits[i] = TUnitChoices[1];//"s"
	return TUnits;
}

function colorIndex(colorStr) {
	for (i=0; i<compositeColors.length; i++)
		if (colorStr==compositeColors[i]) return i;
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
	print("\n"+macroName+" done.\nProcess time: "+
			((getTime()-startTime)/1000)+"s");
	saveLog(logCount);
	clearLogFilesList();
	List.clear();
}

/** Deletes intermediate log files and renames last one
	as a non existing filename */
function clearLogFilesList() {
	for (i=0; i<List.size()-1; i++) {
		fname = List.get(i)+".txt";
		if (File.exists(dir2+fname)) File.delete(dir2+fname);
	}
	fname = List.get(i);
	if (!File.exists(dir2+fname+".txt")) return;
	//print("fname = "+fname);
	fnameNew = substring(fname, 0, lastIndexOf(fname, "_"));
	//print("fnameNew = "+fnameNew);
	if (!File.exists(dir2+fnameNew+".txt")) {
		File.rename(dir2+fname+".txt", dir2+fnameNew+".txt");
		return;
	}
	n=1;
	while (File.exists(dir2+fnameNew+n+".txt")) n++;
	File.rename(dir2+fname+".txt", dir2+fnameNew+n+".txt");
}

/** Saves Log window. Called each time an output image or image group is saved.
	Adds (logCount, logname) to ImageJ's Key-Value List */
function saveLog(logCount) {
	logname = "Log";
	str = concatenateFileFilters(fileFilter, excludingFilter);
	logname = logname + str;
	if (firstPosition!=1 || lastPosition!=-1)
		logname += "_s"+startPosition+"-s"+stopPosition;
	previousLogname = logname;
	logname += "_tmp"+toString(logCount);
	selectWindow("Log");
	IJ.redirectErrorMessages();//seems not avoid macro stops if error
	//print("logname = "+logname);
	saveAs("Text", dir2+logname);
	List.set(logCount, logname);
	if (logCount>0) {
		previousLogFile = previousLogname+"_tmp"+toString(logCount-1)+".txt";
		if (File.exists(dir2+previousLogFile))
			File.delete(dir2+previousLogFile);
	}
}

function concatenateFileFilters(inclFilter, exclFilter) {
	str = "";
	if (inclFilter!="" && inclFilter!=0)
		str += "_include'"+inclFilter+"'";
	if (exclFilter!="" && exclFilter!=0)
		str += "_exclude'"+exclFilter+"'";
	return str;
}

/* Returns part of 'filename' at right of series name */
function getSeriesNameDelimiter(filename) {//end of series name
	if (matches(filename, ".*_w\\d{1}.*"))
		return substring(filename, lastIndexOf(filename, "_w"));
	if (matches(filename, ".*_s\\d{1,3}.*"))
		return substring(filename, lastIndexOf(filename, "_s"));
	if (matches(filename, ".*_t\\d{1,5}.*"))
		return substring(filename, lastIndexOf(filename, "_t"));
	return substring(filename, lastIndexOf(filename, "."));
}

/** Returns string at right of channel name
	'fname' can be filename or seriesName-less filename */
function getChannelRightDelimiter(fname, sername) {
	//print("getChannelRightDelimiter(fname, sername): fname = "+
	//		fname+"    seriesName = "+sername);
	if (startsWith(fname, sername))
		fname = substring(fname, lengthOf(sername));
	if (matches(fname, ".*_s\\d{1,3}.*"))
		return substring(fname, lastIndexOf(fname, "_s"));
	if (matches(fname, ".*_t\\d{1,5}.*"))
		return substring(fname, lastIndexOf(fname, "_t"));
	return substring(fname, lastIndexOf(fname, "."));
}

/* Finds series names in filenames array */
function getSeriesNames(filenames) {
	dbg = false;
	nFiles = filenames.length;
	print("\nnFiles = "+nFiles);
	tmp = newArray(nFiles);
	if (dbg) print("\nFile names\n ");
	for (i=0; i<nFiles; i++) {
		name = filenames[i];
		//print("filename: "+name);
		delim = getSeriesNameDelimiter(name);
		//print("delim = "+delim);
		splittenName = split(name, "("+delim+")");
		tmp[i] = splittenName[0];
	}
	if (dbg) {print("\ntmp:"); for (i=0; i<tmp.length; i++) print(tmp[i]);}
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
	if (dbg) print("nSeries = "+j+1);
	names = Array.trim(names, nSeries);
	//print("\nrawSeriesNames:");
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

/** Renvoie un tableau de dimension nSeries dont les elements sont les
	filenames de chaque serie separes par _2DarraysSplitter */
function getSeriesFilenames(filenames) {
	dbg=false;
	t0 = getTime();
	if (dbg) print("\ngetSeriesFilenames(filenames):");
	filenamesArray = newArray(nSeries);
	n=0;
	for (j=0; j<seriesNames.length; j++) {
		seriesName = seriesNames[j];
		if (dbg) print("\nseriesName = "+seriesName);
		filenamesStr = "";
		for (i=0; i<filenames.length; i++) {
			fname = filenames[i];
			if (!startsWith(fname, seriesName)) continue;
			if (dbg) print("fname = "+fname);
			endOfName = substring(fname, lengthOf(seriesName)-0);
			if (dbg) print ("endOfName = "+endOfName);
			ext = getExtension(endOfName);
			endOfName = substring(endOfName, 0, lastIndexOf(endOfName, ext));
			if (dbg) print ("endOfName = "+endOfName);
			if (endOfName!="" && !startsWith(endOfName, "_w")
					&& !startsWith(endOfName, "_s")
					&& !startsWith(endOfName, "_t")) continue;
			filenamesStr = filenamesStr + filenames[i] + _2DarraysSplitter;
			n++;
		}
		if (dbg) print("filenamesStr = "+filenamesStr);
		filenamesStr = substring(filenamesStr, 0, lengthOf(filenamesStr)-1);
		if (dbg) print("filenamesStr = "+filenamesStr);
		filenamesArray[j] = filenamesStr;
	}
	if (dbg) {
		print("getSeriesFilenames(filenames) end");
		print((getTime()-t0)+"ms");
	}
	return filenamesArray;
}

function getSeriesFileNumbers(seriesFilenamesStr) {
	dbg = false;
	nSeries = seriesFilenamesStr.length;
	if (dbg) print("getSeriesFileNumbers() : nSeries = "+nSeries);
	seriesFileNumbers = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		a = toArray(seriesFilenamesStr[i], _2DarraysSplitter);
		if (dbg) print("\n"+seriesNames[i] + " :");
		for (j=0; j<a.length; j++) {
			if (dbg) print(a[j]);
		}
		seriesFileNumbers[i] = a.length;
	}
	return seriesFileNumbers;
}

/* returns the array of file extensions of channels used in series */
function getExtensions(filenames, seriesName) {
	dbg = false;
	nFiles = getFilesNumber(seriesName);
	channels = getChannelNames(filenames, seriesName);
	nChn = channels.length;
	if (dbg) print("getExtensions(filenames, seriesName): nChn = "+nChn);
	exts = newArray(nChn);
	for (k=0; k<nChn; k++) {
		if (channels[k]==seriesName) channels[k]="";
		j = 0;
		for (i=0; i<filenames.length; i++) {
			name = filenames[i];
			name = seriesNameLessFilename(name, seriesName);
			//excludes filenames without "_":
			//if (!matches(name, "_"+".*")) continue;
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

function isMultiChannel(filenames, seriesName) {
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!startsWith(name, "_w")) continue;
		if (matches(name, "_w\\d.*")) return true;
	}
	return false;
}

/* ¤ Renvoie seriesWithSameChannels :
	 tableau de dimension egale au nb de sequences _w1, _w2, ...,
	 presentes dans dir1 et dont les elements sont les noms des series
	 faites avec une sequence donnee separes par _2DarraysSplitter;
	 pourrait renvoyer les numeros des series (0 a nSeries) a la place
   ¤ Construit le tableau seriesChannelGroups (variable generale) */
function groupSeriesHavingSameChannelSequence() {
	t0=getTime();
	dbg=false;
	nSeqs = channelSequences.length;
	a = newArray(nSeqs);//number of different sequences
	seriesChannelGroups = newArray(nSeries);
	for (i=0; i<nSeqs; i++) {
		a[i] = "";
		for (j=0; j<nSeries; j++) {
			if (seriesChannelSequences[j] == channelSequences[i]) {
				a[i] = a[i] + seriesNames[j] + _2DarraysSplitter;
				seriesChannelGroups[j] = i;
			}
		}
		a[i] = substring(a[i], 0, lengthOf(a[i]) - 1);
	}
	if (dbg) {
		print("\ngroupSeriesHavingSameChannelSequence():");
		for (i=0; i<a.length; i++) print("a["+i+"]="+a[i]);
		print((getTime()-t0)+"ms");
	}
	return a;
}

/** Returns channelSequences
	Renvoie un tableau de dimension egale au nb de sequences _w1, _w2, ...,
	presentes dans dir1 et dont les elements sont les _w1, _w2, ... separes par
	_2DarraysSplitter (reduction du tableau seriesChannelSequences() renvoye
	par getSeriesChannelSequences() a ses elements non redondants) */
function getChannelSequences(seriesChannelSequences) {
	t0=getTime();
	dbg=true;
	n = seriesChannelSequences.length;//= nSeries
	seqs = newArray(n);
	seqs[0] = seriesChannelSequences[0];
	nSeqs = 1;
	for (i=1; i<n; i++) {
		newSeq = true;
		for (j=0; j<=i; j++) {
			if (seriesChannelSequences[i] == seqs[j]) {
				newSeq = false;
				break;
			}
		}
		if (newSeq)
			seqs[nSeqs++] = seriesChannelSequences[i];
	}
	if (dbg) print("nSeqs = "+nSeqs);
	seqs = Array.trim(seqs, nSeqs);
	if (dbg) {
		print("\ngetChannelSequences(seriesChannelSequences):");
		for (i=0; i<nSeqs; i++) print("seqs["+i+"]="+seqs[i]);
		print((getTime()-t0)+"ms");
	}
	return seqs;
}

/** Returns seriesChannelSequences,
	an array of dimension nSeries in which elements are the 
	channelNames separated by '_2DarraysSplitter'
	May fail if input folder contains an output image:
	solved by removeSinglets(list) */
function getSeriesChannelSequences() {//seems ok
	t0=getTime();
	dbg=false;
	dbg2=false;
	if (dbg) {
		print("\ngetSeriesChannelSequences():");
		print("nSeries = "+nSeries);
	}
	seriesChannels = newArray(nSeries);
	for (i=0; i<nSeries; i++) {
		if (dbg) print("");
		if (dbg) print("seriesFilenamesStr["+i+"]="+seriesFilenamesStr[i]);
		fnames = split(seriesFilenamesStr[i], _2DarraysSplitter);
		chn = newArray(fnames.length);
		if (dbg) print("fnames.length = "+fnames.length);
		alreadyAdded = newArray(fnames.length);
		for (j=0; j<fnames.length; j++) {
			chn[j] = "";
			alreadyAdded[j] = "";
		}
		if (dbg) print("seriesNameLess names");
		k = 0;
		for (j=0; j<fnames.length; j++) {
			seriesNameLessName = substring(fnames[j],
					lengthOf(seriesNames[i]), lengthOf(fnames[j]));
			if (dbg) print(seriesNameLessName);
 			delim = getChannelRightDelimiter(seriesNameLessName,seriesNames[i]);
			if (dbg) print("ChannelRightDelimiter = delim = "+delim);
			index1 = lastIndexOf(seriesNameLessName, "_w");
			if (index1<0) continue;
			index2 = indexOf(seriesNameLessName, delim);
			str = substring(seriesNameLessName, index1, index2);
			if (dbg2) print("str = "+str);
			addit = true;
			if (dbg2) {
				print("j = "+j);
				print("k = "+k);
				print("addit = "+addit);
			}
			if (j==0) {
				if (dbg2) print("chn[k] = str;");
				chn[k] = str;
				alreadyAdded[k++] = str;
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
					alreadyAdded[k++] = str;
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
			if (dbg) print("chn["+j+"]="+chn[j]);
			seriesChannels[i] = seriesChannels[i] + chn[j] + _2DarraysSplitter;
		}
		if (endsWith(seriesChannels[i], _2DarraysSplitter)) {
			seriesChannels[i] = substring(seriesChannels[i],
				0, lastIndexOf(seriesChannels[i], _2DarraysSplitter));
		}
	}
	undefinedChannels = 0;
	print("getSeriesChannelSequences():");
	for (i=0; i<nSeries; i++) {
		if (seriesChannels[i]=="") {
			//seriesChannels[i] = "Undefined_Channel_"+undefinedChannels;
//NO			//seriesChannels[i] = "Undefined_Channel";
			undefinedChannels++;
		}
		print("seriesChannels["+i+"]="+seriesChannels[i]);
	}
	if (dbg) print((getTime()-t0)+"ms");
	return seriesChannels;
}//getSeriesChannelSequences()

function seriesNameLessFilename(filename, seriesName) {
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

/** Returns 'str' where chars forbidden in Windows filenames have been removed.
	'varName' is the name of the variable having the value 'str'.
	'varName' is only for tracing / documenting. */
function removeFilenamesForbiddenChars(varName, str) {
	dbg = false;
	osName = getInfo("os.name");
	if (indexOf(osName, "Win") >= 0)
		fc = newArray("\\\\","/",":","\\*","\\?","\"","<",">","\\|");
	else if (indexOf(osName, "Linux") >= 0)
		fc = newArray("/","\\*","\\?");//to be completed and verified
	else if (indexOf(osName, "Mac") >= 0)
		fc = newArray("/","\\*","\\?");//to be completed and verified
	str2 = str;
	if (dbg) print(varName+" = "+str2);
	for (i=0; i<fc.length; i++) {
		r = replace(str2, fc[i], "");
		if (r!=str2) {
			str2 = r;
			if (dbg) print(varName+" = "+str2);
		}
	}
	return str2;
}

function spacesAndTabsToRegexMetachars(str) {
	str2 = replace(str, " ", "\\s");
	str2 = replace(str2, "	", "\\t");
	return str2;
}

/** Returns Regular Expression built on 'str' to be used as is or concatenated 
	with other regular expressions in matches(string, regex) macro function */
function toRegex(str) {
	//print("\ntoRegex("+str+")");
	//print("str = "+str);
	str2 = str;
	for (i=0; i<regexMetachars.length; i++)
		str2 = replace(str2, regexMetachars[i], "\\"+regexMetachars[i]);
	//print("str2 = "+str2);
	//str2 = replace(str2, " ", "\\s");
	//should replace space with \s and tab with \t ?
	return str2;
}

/** Returns array of channel names used in series named 'seriesName' 
	'filenames' array of filenames
	'seriesName' name of the series from which get channel names */
function getChannelNames(filenames, seriesName) {
	print("\ngetChannelNames(filenames, "+seriesName+")");
	seriesNameRE = toRegex(seriesName);
	print("seriesNameRE = "+seriesNameRE);
	dbg=false;
	nFiles = getFilesNumber(seriesName);
	if (dbg) {
		print("\n"+seriesName);
		print("getChannelNames(filenames, seriesName): nFiles in series = "
			+nFiles);
	}
	tmp = newArray(nFiles+1);
	j=0;
	for (i=0; i<filenames.length; i++) {
		fname = filenames[i];
		if (!startsWith(fname, seriesName)) continue;
		//if (!matches(fname, ".*"+"_w\\d"+".*")) continue;//1
		if (!matches(fname, seriesNameRE+"_w\\d"+".*")) continue;//safer than 1
		if (dbg) print("filenames["+i+"] = "+fname);
		delim = getChannelRightDelimiter(fname, seriesName);
		if (dbg) print("ChannelRightDelimiter = delim = "+delim);
		index1 = lengthOf(seriesName);
		index2 = indexOf(fname, delim);
		str = substring(fname, index1, index2);
		tmp[j++] = str;
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
	if (dbg) {
		print("nChn="+j);
		for (i=0; i<channels.length; i++) print(channels[i]);
	}
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

/** Returns theoretical number of positions in series named 'seriesName'.
	doesn't check if corresponding files exist in 'filenames' list */
function getPositionsNumber(filenames, seriesName) {
	dbg=false;
	if (dbg) print("getPositionsNumber(filenames, "+seriesName+")");
	k = getIndex(seriesName, seriesNames);
	mp = multipositionSeries[k];
	if (!mp) return 1;
	ts = timeSeries[k];
	positionDelimiter = ".";
	if (ts) positionDelimiter = "_t";
	nFiles = getFilesNumber(seriesName);
	if (dbg) print("nFiles in series "+seriesName+" : "+nFiles);
	j=0;
	nPositions = 1;
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		if (dbg) print(seriesName);
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (matches(name, ".*_s\\d{1,3}.*")) {
			splittenName = split(name, "(_s)");
			str = splittenName[splittenName.length-1];
			posStr = substring(str,0,indexOf(str,positionDelimiter));
			n = parseInt(posStr);
			nPositions = maxOf(nPositions, n);
			j++;
		}
		if (j==nFiles) break;
	}
	return nPositions;
}

function getIndex(seriesName, seriesNames) {
	for (i=0; i<seriesNames.length; i++) {
		if (seriesNames[i] != seriesName) continue;
		return i;
	}
	return 0;
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
	dbg=false;
	k = getIndex(seriesName, seriesNames);
	if (!timeSeries[k]) return 1;
	timeDelimiter = ".";
	nFiles = getFilesNumber(seriesName);
	if (dbg) {
		print("getFramesNumber(filenames, seriesName) nFiles in series = "+
			nFiles);
		print("filenames:");
	}
	j=0;
	nFrames = 0;
	for (i=0; i<filenames.length; i++) {
		name = filenames[i];
		name = seriesNameLessFilename(name, seriesName);
		if (!matches(name, "_"+".*")) continue;
		if (dbg) print(name);
		if (matches(name, ".*_t\\d{1,5}.*")) {
			splittenName = split(name, "(_t)");
			str = splittenName[splittenName.length-1];
			if (dbg) print("str: "+str);
			timeStr = substring(str, 0, indexOf(str, timeDelimiter));
			if (dbg) print("posStr: "+posStr);
			tpoint = parseInt(timeStr);
			nFrames = maxOf(nFrames, tpoint);
			j++;
		}
		if (j==nFiles) break;
	}
	return nFrames;
}

/** Returns array of frame numbers for each channel
	of series corresponding to 'seriesIndex' */
function getFrameNumbers(filenames, seriesIndex) {
	dbg=false;
	seriesName = seriesNames[seriesIndex];
	ts = timeSeries[seriesIndex];
	chnSeq = toArray(seriesChannelSequences[seriesIndex], _2DarraysSplitter);
	frameNumbers = newArray(chnSeq.length);
	for (k=0; k<chnSeq.length; k++) {
		nframes = 1;
		if (ts) {
			timeDelimiter = ".";
			nFiles = getFilesNumber(seriesName);
			if (dbg) print("getFramesNumbers(filenames, seriesName)"+
						" nFiles in series = "+nFiles);
			j=0;
			nframes = 0;
			if (dbg) print("filenames:");
			for (i=0; i<filenames.length; i++) {
				name = filenames[i];
				name = seriesNameLessFilename(name, seriesName);
				if (!matches(name, "_"+".*")) continue;
				if (!matches(name, chnSeq[k]+".*")) continue;
				if (dbg) print(name);
				if (matches(name, ".*_t\\d{1,5}.*")) {
					splittenName = split(name, "(_t)");
					str = splittenName[splittenName.length-1];
					if (dbg) print("str: "+str);
					timeStr = substring(str, 0, indexOf(str, timeDelimiter));
					if (dbg) print("posStr: "+posStr);
					tpoint = parseInt(timeStr);
					nframes = maxOf(nframes, tpoint);
					j++;
				}
				if (j==nFiles) break;
			}
		}
		frameNumbers[k] = nframes;
		print("nframes["+k+"]="+nframes);
	}
	return frameNumbers;
}

function getExtension(filename) {
	if (indexOf(filename, ".")<0) return "";
	s = substring(filename, lastIndexOf(filename, "."), lengthOf(filename));
	return s;
}

/** Returns an array of same length as chns
	chns: array of wave names (illumination setting names)
	Example:
	if chns = {"w1CSU405, "_w2CSU488 CSU561", "_w3CSU488 CSU561"}
	returns {false, true, true} */
function isDualCameraChannel(chns) {//Not used
	a = newArray(chns.length);
	for (i=0; i<chns.length-1; i++) {
		str1 = chns[i]; str2 = chns[i+1]; 
		if (substring(str2, 3,
				lengthOf(str2))==substring(str1, 3, lengthOf(str1))) {
			a[i] = true;
			a[i+1] = true;
		}
	}
	return a;
}

/** Returns true if chns contains a dual channel sequence, i.e. 
	a sequence like ("_w2CSU488 CSU561", "_w3CSU488 CSU561").
	chns : array of wavelengths
	Returns false if dual channels are stiched in a single image */
function hasDualChannelSet(chns) {
	if (chns.length<2) return false;
	//dual camera channels must have same illumination settings
	//and be consecutive
	for (i=0; i<chns.length-1; i++) {
		str1 = chns[i]; str2 = chns[i+1]; 
		if (substring(str2, 3,
				lengthOf(str2))==substring(str1, 3, lengthOf(str1))) {
			return true;
		}
	}
	return false;
}

//Il faut chercher dans les metadata car on peut acquerir des
//images en dual camera sans cocher la case Multichannel, ce qui fait que
//les noms ne contiennent pas _w1, _w2 etc.
//Par ailleurs, Metamorph peut etre configure de sorte que les noms des
//images ne coportent pas l'indication de l'illumination setting complet
//mais seulement _w1, _w2 etc.

/** Returns true if chns contains a dual channel sequence but only one
	image containing both channels. */
function hasDualChannelSingleImage(chns) {
	for (i=0; i<chns.length-1; i++) {
		for (j=0; j<dualCameraSettingsInImagenames.length; j++)
			if (chns[i]==dualCameraSettingsInImagenames[j]) {
				if (chns.length==1 ||
						chns[i+1]!=dualCameraSettingsInImagenames[j])
					return true;
		}
	}
	return false;
}

function toLitteral(regex) {
	dbg = false;
	str = regex;
	if (dbg) print("toLitteral(): str = "+str);
	str = replace(str, "\\(\\\\s\\)", " ");//space
	str = replace(str, "\\(\\\\t\\)", "	");//tab
	if (dbg) print("toLitteral(): str = "+str);
	return str;
}

/** Returns wave names in 'chns'
	'chns' array of wave names (illumination setting names)
	'separator' the character between two wavelengths in 'chns'
	Assumes dual channel names are separated by a space ("\\s")
	Example:
	if chns = {"_w1CSU405, "_w2CSU488 CSU561", "_w3CSU488 CSU561"}
	returns {"CSU405", "CSU488", " 561"} */
function getIlluminationSettings(chns, separator) {
	dbg=false;
	if (!hasDualChannelSet(chns)) {
		print("Series has no DualChannelSet");
		return chns;
	}
	isRegex = startsWith(separator, "(") && endsWith(separator, ")");
	if (dbg) print("isRegex="+isRegex);
	separatorRE = separator;
	separatorLitteral = separator;
	if (isRegex) {
		separatorLitteral = toLitteral(separator);
		if (dbg) print("separatorLitteral = "+separatorLitteral);
	}
	else
		separatorRE = "("+separator+")";
	print("Series has a DualChannelSet");
	a = newArray(chns.length);
	for (i=0; i<chns.length-1; i++) {
		a[i] = chns[i];
		str1 = chns[i]; str2 = chns[i+1];
		s1 = substring(str1, 3, lengthOf(str1));
		s2 = substring(str2, 3, lengthOf(str2));
		if (substring(str2, 3, 
				lengthOf(str2))==substring(str1, 3, lengthOf(str1))) {
			prefix1 = substring(str1, 0, 3);
			prefix2 = substring(str2, 0, 3);
			a[i+1] = chns[i+1];
			b = split(str1, separatorRE);
			if (b.length==2) {
				if (firstDualChannelIllumSetting_is_w1) {
					a[i] = b[0];
					a[i+1] = prefix2 + separatorLitteral + b[1];
				}
				else {
					a[i+1] = b[0];
					a[i] = prefix2 + separatorLitteral + b[1];
				}
			}
			i++;
		}
	}
	if (dbg) {
		print("\ngetIlluminationSettings");
		for (i=0; i<a.length; i++)
			print("getIlluminationSettings(): illuminationSettings["+i+"]="+
				a[i]);
	}
	return a;
}

function initChannelColorIndexes(chns) {
	dbg = false;
	illumSettings = getIlluminationSettings(chns, dualChannelSeparator);
	print("\ninitChannelColorIndexes(chns):");
	for (i=0; i<illumSettings.length; i++)	
		print("illumSettings["+i+"] = "+illumSettings[i]);
	idx = newArray(chns.length);
	for (i=0; i<chns.length; i++) {
		found = false;
		for (j=0; j<redDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(redDeterminants[j]))>0) {
				idx[i] = 0;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<greenDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(greenDeterminants[j]))>0) {
				idx[i] = 1;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<blueDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(blueDeterminants[j]))>0) {
				idx[i] = 2;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<grayDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(grayDeterminants[j]))>0) {
				idx[i] = 3;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<cyanDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(cyanDeterminants[j]))>0) {
				idx[i] = 4;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<magentaDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(magentaDeterminants[j]))>0) {
				idx[i] = 5;
				found = true;
				break;
			}
			if (found) continue;
		}
		for (j=0; j<yellowDeterminants.length; j++) {
			if (indexOf(toLowerCase(illumSettings[i]),
					toLowerCase(yellowDeterminants[j]))>0) {
				idx[i] = 6;
				found = true;
				break;
			}
			if (found) continue;
		}
	}
//	 makeColorsDifferent = true;
//	 channelColors = getChannelColors(chns, makeColorsDifferent);//?
	if (dbg) for (i=0; i<idx.length; i++)
		print("channelIndexes["+i+"] = "+idx[i]);
	ensureColorsAreDifferent = true;
	if (ensureColorsAreDifferent)
		idx = ensureColorIndexesAreDifferent(idx);
	return idx;
}//initChannelColorIndexes(chns)

function computeColorIndexes(chns, outputColors) {
	nchn = chns.length;
	print("computeColorIndexes(chns, outputColors):");
	for (i=0; i<nchn; i++) {
		print("chns["+i+"] = "+chns[i]);
		print("outputColors["+i+"] = "+outputColors[i]);
	}
	idxs = newArray(nchn);
	for (i=0; i<nchn; i++)
		for (j=0; j<nchn; j++)
			if (chns[i]==chns[j]) {
				idxs[i] = colorIndex(outputColors[j]);
				break;
			}
	return idxs;
}

/** To be invoked for each series independently to avoid attempts merging
	two images in the same channel; channels have to be chosen in the
	{"c1", ..., "c7"} set and must be different from each other, as in the 
	Image>Color>"Merge Channels..." command. */
function ensureColorIndexesAreDifferent(colourIndexes) {
	nchn = colourIndexes.length;
	idxs = newArray(nchn);
	for (i=0; i<nchn; i++)
		idxs[i] = colourIndexes[i];
	for (i=nchn-1; i>=0; i--) {
		c=nchn-1;
		for (j=i-1; j>=0; j--) {//cycle until find free index 
			if (idxs[j]==colourIndexes[i]) {
				c--;
				idxs[j] += 1;
				if (idxs[j]==7) idxs[j] = 0;
			}
			if (c==0) break;
		}
	}
	return idxs;
}

function ensureColorIndexesAreDifferent_bottomUp(colourIndexes) {
	nchn = colourIndexes.length;
	idxs = newArray(nchn);
	for (i=0; i<nchn; i++)
		idxs[i] = colourIndexes[i];
	for (i=0; i<nchn; i++) {
		c=0;
		for (j=i+1; j<nchn; j++) {//cycle until find free index 
			if (idxs[j] == colourIndexes[i]) {
				c++;
				idxs[j] += 1;
				if (idxs[j] == 7) idxs[j] = 0;
			}
			if (c==6) break;
		}
	}
	return idxs;
}

/** reorders chns, the array of channels, in growing order of c1, c2, ..., c7
	applies the same order to 'array' and returns its reordered version
	'array': the array to be reordered
	'chns': the channel names array used to reorder 'array'
	'channelCompositeStrings': the array of "c"+i strings, i=1,7
	defining channel colors and positions in the composite image
	'array' and 'chns' must have same length */
function reorderArray(array, chns, channelCompositeStrings) {
	dbg=false;
	nchn = chns.length;
	array2 = Array.copy(array);
	chns2 = Array.copy(chns);
	chnPositions = newArray(nchn);
	for (i=0; i<nchn; i++)
	 	chnPositions[i]=parseInt(substring(channelCompositeStrings[i],1));
	for (i=0; i<nchn; i++) {
		for (j=i; j<nchn; j++) {
			if (chnPositions[j] < chnPositions[i]) {
				tmp = chnPositions[j];
				chnPositions[j] = chnPositions[i];
				chnPositions[i] = tmp;
				if (dbg) print("chnPositions["+j+"] < chnPositions["+i+"]");
				tmp = chns2[j];
				chns2[j] = chns2[i];
				chns2[i] = tmp;
				tmp = array2[j];
				array2[j] = array2[i];
				array2[i] = tmp;
			}
		}
	}
	if (dbg) for (i=0; i<array2.length; i++)
		print("\nInside reorderArray(): reorderedArray["+i+"]="+array2[i]);
	return array2;
}

function hasDuplicateColorIndex(colourIndexes) {
	for (i=0; i<colourIndexes.length; i++)
		for (j=i+1; j<colourIndexes.length; j++)
			if (colourIndexes[j]==colourIndexes[i]) return true;
	return false;	
}

/* returns an array of length 'chns' with elements "c1","c2",...,"c7" */
function getChannelColors(chns, ensureColorsAreDifferent) {
	dbg = false;
	idx = initChannelColorIndexes(chns);
	cycle = 1;
	hasDuplicateColor = false;
	while (hasDuplicateColorIndex(idx) && cycle++ < 7) {
		if (ensureColorsAreDifferent) idx=ensureColorIndexesAreDifferent(idx);
		if (dbg) {
			print("cycle="+cycle);
			for (i=0; i<idx.length; i++) print("idx["+i+"]="+idx[i]);
		}
	}
	if (dbg) for (i=0; i<idx.length; i++) print("idx["+i+"]="+idx[i]);
	channelColorIndexes = newArray(idx.length);
	for (i=0; i<idx.length; i++)
		channelColorIndexes[i] = idx[i];
	clrs = newArray(chns.length);
	for (i=0; i<idx.length; i++) {
		clrs[i] = compositeChannels[idx[i]];
		if (dbg) print("clrs["+i+"]="+clrs[i]);
	}
	return clrs;
}

/////////////////////////////////////// metadata processing
/* Add metadata: 
<prop id="look-up-table-name" type="string" value="Monochrome"/>
<prop id="wavelength" type="float" value="630"/> */
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

//Slow part: index1, ..., index4 calculation
/** Assigns variable corresponding to MMMetadataEntries[paramIndex] 
	(pixelsX etc.) to value found in tag explored from searchStartIndex
	and returns the new searchStartIndex for next call */
function extractValue(tag, paramIndex, searchStartIndex) {
	lineEndsWith_BackslahGreaterThan = false;
	t0=getTime();
	dbg = false;
	if (tag=="" || tag==0) return -1;
	if (dbg) print("extractValue(tag, param, searchStartIndex)");
	if (indexOf(tag,"MetaMorph")<0) return -1;
	i=paramIndex;
	param = MMMetadataEntries[i];
	index1 = indexOf(tag, param, searchStartIndex);
	if (index1<0) return -1;
	index2 = indexOf(tag, "value=", index1);
	index3 = indexOf(tag, "/>", index2);
	if (index3==-1) {
		index3 = indexOf(tag, "\">", index2);
		lineEndsWith_BackslahGreaterThan = true;
	}
	index4 = indexOf(tag, "/>", index3);
	if (index4==-1) index4 = indexOf(tag, "\">", index3);
	if (lineEndsWith_BackslahGreaterThan)
		valStr = substring(tag, index2+7, index3-0);
	else
		valStr = substring(tag, index2+7, index3-1);
	if (dbg) print(param + " = "+valStr);
	if (i==0) pixelsX = parseInt(valStr);
	else if (i==1) pixelsY = parseInt(valStr);
	else if (i==2) bitsPerPixel = parseInt(valStr);
	else if (i==3) {
		isSpatiallyCalibrated = false;
		if (valStr=="on")
			isSpatiallyCalibrated = true;
	}
	else if (i==4) xCalibration = parseFloat(valStr);
	else if (i==5) yCalibration = parseFloat(valStr);
	else if (i==6) spatialCalibrationIUnit = valStr;
	else if (i==7) mmImageName = valStr;
	else if (i==8) acquisitionTimeStr = valStr;
	else if (i==9) {
		modificationTimeStr = valStr;
		searchIndexForZPosition = index4;
	}
	else if (i==10) zPosition = parseFloat(valStr);
	else if (i==11) cameraBinningX = parseInt(valStr);
	else if (i==12) cameraBinningY = parseInt(valStr);
	else if (i==13) illumSetting = valStr;
	else if (i==14) objective = valStr;
	else if (i==15) numberOfPlanes = parseInt(valStr);
	if (dbg) print("numberOfPlanes = "+numberOfPlanes);
	//print("extractValue(tag, param, searchStartIndex)");
	//print((getTime()-t0)+"ms");
	return index4;
}

//benchMarkOpen1stSlice();
function benchMarkOpen1stSlice() {
	print("");
	t0=getTime;
	//ATTENTION : si fichier ci-dessous dans dir1, plantage car non rejete
	path = "D:/Users/Celine/20180627_partie/"+
			"test-2_w2SPI 561 mCherry_s1_t2_1stSlice.tif";//1 slice
	path = "D:/Users/Celine/20180627_partie/test-2_w2SPI 561 mCherry_s1_t2.TIF";
	for (i=0; i<20; i++) {
		t1=getTime;
		//open(path, n) provides same z-position for n=1 & n=21
		open(path, 1);//42 ms
		open(path, 21);//152 ms
		print((getTime-t1)+"ms");
		close();
	}
	meanTime = (getTime-t0)/20;
	print("\nmeanOpeningTime="+meanTime);
}

/* Populates variables from metadata
* call("TIFF_Tags.getTag", path, tagNum, IFD) takes 2x the time to open
* a 25 MB file (500 ms).
* Consequences:
* - Use call("TIFF_Tags.getTag", path, tagNum, IFD) only if need to get 
*   z-position of last slice (unaccessible by getImageInfo())
* - Else use getImageInfo() from image of interest (preferably active image);
*   unless huge image, faster than "TIFF_Tags.getTag(args)".
* - If need to open the image to get Info, use "open(path, 1)", working also if
*   only 1 slice. Works more than 10x faster than "TIFF_Tags.getTag" for a 25 MB
*   stack of 21 slices (1.1 MB / slice).
*   execute benchMarkOpen1stSlice() to verify */
function getImageMetadata(path, imgID, use_tiff_tags_plugin) {
	id=0;
	if (nImages-nImages0 > 0) id = getImageID;
	dbg=false;
	tagNum = 270;
	IFD=1;
	tag = getDescriptionTag(path, IFD, imgID, use_tiff_tags_plugin);
	if (false) {
		regex = "(/{0,1}>\\s</{0,1})";
		infos = split(tag,regex);
		print("\ninfos");
		for (i=0; i<infos.length; i++) print(infos[i]);	print("");
	}
	if (tag=="" || tag==0) return false;
	if (indexOf(tag, "<MetaData>")<0) return false;
	if (dbg) print("getImageMetadata(path, imgID, use_tiff_tags_plugin="+
			use_tiff_tags_plugin+")");
	searchStartIndex = 0;
	t0=getTime();
	for (i=0; i<MMMetadataEntries.length; i++) {
	 	searchStartIndex = extractValue(tag, i, searchStartIndex);
		if (dbg) {
			print("searchStartIndex="+searchStartIndex);
			print("MMMetadataEntries["+i+"]="+MMMetadataEntries[i]);
			print("acquisitionTimeStr="+acquisitionTimeStr);
		}
	 	if (searchStartIndex==-1) return false;
	}
	if (numberOfPlanes>1) {
		if (tiff_tags_plugin_installed) {
			zPositionBegin = zPosition;
			IFD = numberOfPlanes;
			t0=getTime();
			tag = call("TIFF_Tags.getTag", path, tagNum, IFD);
			print("calling TIFF_Tags plugin");
			print((getTime()-t0)+"ms");		
			if (indexOf(tag,"<MetaData>")<0)
				print("Could not determine z-calibration");
			extractValue(tag, 10, searchIndexForZPosition);//10 : z-position
			zPositionEnd = zPosition;
		}
		else
			print("\nCannot get zPositionEnd, tiff tags plugin not found");
	}
	if (dbg) print("acquisitionTimeStr="+acquisitionTimeStr);
	if (id<0) selectImage(id);
	return true;
}

function getAcquisitionTimeStr(path, imgID) {
	if (nImages>0) id = getImageID();
	if (imgID>=0 || !isOpen(imgID)) {
		open(path, 1);
		title = getTitle;
		tag = getImageInfo();
		close();
	}
	else {
		selectImage(imgID);
		title = getTitle;
		tag = getImageInfo();
	}
	print("getDescriptionTag("+title+")");
	paramIndex = 8;
	searchStartIndex = 0;
	extractValue(tag, paramIndex, searchStartIndex);
	if (id<0 && isOpen(id)) selectImage(id);
}

/* Called by getImageMetadata() */
function getDescriptionTag(path, IFD, imgID, use_tiff_tags_plugin) {
	curID = 0;
	if (nImages-nImages0>0) curID = getImageID();
	dbg=false;
	tag = "";
	tagNum = 270;
	if (use_tiff_tags_plugin && tiff_tags_plugin_installed) {
		tag = call("TIFF_Tags.getTag", path, tagNum, IFD);
		if (tag!="") {
			if (curID<0 && isOpen(curID)) selectImage(curID);
			return tag;
		}
	}
	if (isOpen(imgID)) {
		selectImage(imgID);
		print("getDescriptionTag of open image ("+getTitle+")");
		tag = getImageInfo();//returns info of 1st slice only
	}
	else {
		open(path, 1);
		print("getDescriptionTag("+getTitle+")");
		tag = getImageInfo();
		close();
	}
	if (dbg) {
		print("\nDescription tag:");
		print(tag);
	} 
	if (curID<0 && isOpen(curID)) selectImage(curID);
	return tag;
}

function computeZInterval() {
	if (numberOfPlanes<2) return 0;
	ZInterval = abs(zPositionEnd-zPositionBegin) / (numberOfPlanes-1);
	return ZInterval;
}

/* calculates acquisition year, month, day & time in milliseconds */
function computeAcquisitionDayAndTime(timeStr) {
	dbg=false;
	if (timeStr=="" || timeStr==0) return false;
	acquisitionDay = NaN;
	acquisitionTime = NaN;
	if (dbg) print("timeStr="+timeStr);
	date = substring(timeStr, 0, 8);
	year = parseInt(substring(date, 0, 4));
	month = parseInt(substring(date, 4, 6));
	day = parseInt(substring(date, 6, 8));
	tStr = substring(timeStr, 9, lengthOf(timeStr));
	if (dbg) print("tStr="+tStr);
	hourOfDay = parseInt(substring(tStr, 0, 2));
	minute = parseInt(substring(tStr, 3, 5));
	second = parseInt(substring(tStr, 6, 8));
	//timeStr: 20191125 13:56:21.19 tStr: 13:56:21.19
	millisecond = parseInt(substring(tStr, 9, lengthOf(tStr)));
	if (dbg) {
		print("year="+year);
		print("month="+month);
		print("day="+day);
		print("hourOfDay="+hourOfDay);
		print("minute="+minute);
		print("second="+second);
		print("millisecond="+millisecond);
	}
	timeMillis = millisecond+(second+(minute+hourOfDay*60)*60)*1000;
	acquisitionYear = year;
	acquisitionMonth = month;
	acquisitionDay = day;
	acquisitionTime = timeMillis;
	return true;
}

/** Converts oldUnit value to newUnit
	Does nothing if oldUnit or newUnit unknown */
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
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm")
			val /= 1000;
		else if (oldUnit=="cm") val *= 10;
		else if (oldUnit=="m") val *= 1000;
	}
	else if (newUnit=="cm") {
		if (oldUnit=="nm") val /= 10000000;
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm")
			val /= 10000;
		else if (oldUnit=="mm") val /= 10;
		else if (oldUnit=="m") val *= 100;
	}
	else if (newUnit=="m") {
		if (oldUnit=="nm") val /= 1000000000;
		else if (oldUnit=="micron"||oldUnit=="um"||newUnit=="µm")
			val /= 1000000;
		else if (oldUnit=="mm") val /= 1000;
		else if (oldUnit=="cm") val /= 100;
	}
	return val;
}

function computeMonthLengths(year) {
	lengths = newArray(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	/* Adapted from https://fr.wikipedia.org/wiki/Ann%C3%A9e_bissextile
	 * l'année est bissextile (a 366 jours) :
	 * si elle est divisible par 4 et non divisible par 100
     * ou si elle est divisible par 400. */
	bisextile = year%4==0 && year%100!=0 || year%400==0;
	if (bisextile) lengths[1] = 29;
	return lengths;
}

/** Returns days between two timepoints
	acquisitionYears, acquisitionMonths, acquisitionDays: arrays of dimension 2; 
	first element = timepoint 0, second element = timepoint 1 */
function daysInterval(Years, Months, Days) {
	dbg=true;
	monthLengths0 = computeMonthLengths(Years[0]);
	monthLengths1 = computeMonthLengths(Years[1]);
	nDays = 0;
	if (Years[1]==Years[0]) {
		if (Months[1]==Months[0])
			return Days[1]-Days[0];
		else {
			nDays = Days[1]-1;
			for (j=Days[0]; j<monthLengths0[Months[0]]; j++)
				nDays++;
			for (i=Months[0]+1; i<Months[1]; i++)
				nDays += monthLengths0[i]; 
			if (dbg) print("nDays="+nDays);
			return nDays;
		}
	}
	return 0;//1 ?
}

/** Returns time interval in ms between first and last frame
	Fails if timelapse crosses new year */
function computeTimelapseDuration(acquisitionYears, acquisitionMonths, 
		acquisitionDays, acquisitionTimes) {
	dbg=false;
	//dt = 0;
	if (dbg) print("acquisitionTimes[1]="+acquisitionTimes[1]);
	if (dbg) print("acquisitionTimes[0]="+acquisitionTimes[0]);
	dt = acquisitionTimes[1] - acquisitionTimes[0];
	days = acquisitionDays[1] - acquisitionDays[0];
	months = acquisitionMonths[1] - acquisitionMonths[0];
	years = acquisitionYears[1] - acquisitionYears[0];
	if (days>0 && months==0) //crossing days but not month(s)
		dt += days*24*60*60*1000;
	else if (years==0 && months!=0) {//crossing month(s) but not years
		days = daysInterval(acquisitionYears,
				acquisitionMonths, acquisitionDays);
		dt += days*24*60*60*1000;
	}
	if (dbg) print("dt="+dt);
	return dt;
}

/** not used
	extracts parameter 'param' as a string from description tag of a 
	Metamorph image */
function extractValueAsString(tag, param) {
	dbg = true;
	if (dbg) print(tag);
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
	if (dbg) print(param+"="+str);
	return str;
}
/////////////////////////////////////// End metadata processing


/* AUTRE PROCEDURE pour la gestion des LUT
* ajouter des Combobox permettant de choisir la LUT pour
* chaque channelGroup -> lutNames. 
* Exemple: 3 channelGroups: 
* channelGroupslutNames = {"Red,Fire,Grays", "Green,Blue,Red", "Red,Green"};
* Pour recuperer la LUT chn pour channelGroupIndex:
* lutNames = toArray(channelGroupslutNames[channelGroupIndex]);
* lutName = lutNames[chn];
* - creer une image 8-bit 1x1x1
* - run(lutName);
* - getLut(reds, greens, blues);
* Pour assigner la LUT au canal chn:
* - selectImage(inputImageID);
* - Stack.setChannel(chn);
* - setLut(reds, greens, blues);
* refermer l'image auxiliaire
*/

/** seriesName: String
	channelStr: String (_w1RFP or similar)
	position: 1, 2, 3, ..., nPositions
	timepoint: 1, 2, 3, ..., nFrames
	extension: .TIF, .tif, .STK, .stk */
function buildInputFilePath(
		seriesName, channelStr, position, timepoint, extension) {//not used
	path = dir1;
	path += seriesName;
	path += channelStr;
	path += "_s"+position;
	path += "_t"+timepoint;
	path += extension;
	return path;
}

function setLuts(imgID, channelColorIndexes) {
	if (!isOpen(imgID)) return;
	id = getImageID();
	selectImage(imgID);
	Stack.getDimensions(width, height, nchannels, slices, frames);
	for (c=1; c<=nchannels; c++) {
		index = channelColorIndexes[c-1];
		colorStr = colorLutNames[index];
		lut = makeLut1D(colorStr);
		reds = Array.slice(lut,0,256);
		greens = Array.slice(lut,256,512);
		blues = Array.slice(lut,512,768);
		Stack.setChannel(c);
		setLut(reds, greens, blues);
	}
	selectImage(id);
}

/** Returns LUT as a 1D array(3*256)
	000-255 : reds
	256-511 : greens
	512-767 : blues
	can't return 3 arrays(256) */
function makeLut1D(colorStr) {
	black = newArray(256);
	ramp = Array.getSequence(256);
	if (colorStr=="Red")
		lut = concatenateArrays(ramp, black, black);
	else if (colorStr=="Green")
		lut = concatenateArrays(black, ramp, black);
	else if (colorStr=="Blue")
		lut = concatenateArrays(black, black, ramp);
	else if (colorStr=="Cyan")
		lut = concatenateArrays(black, ramp, ramp);
	else if (colorStr=="Magenta")
		lut = concatenateArrays(ramp, black, ramp);
	else if (colorStr=="Yellow")
		lut = concatenateArrays(ramp, ramp, black);
	else //Grays
		lut = concatenateArrays(ramp, ramp, ramp);
	return lut;
}

function concatenateArrays(array1, array2, array3) {
	a = Array.concat(array1,array2);
	return Array.concat(a,array3);
}

/* Sets lut of active channel of active image for all timepoints and slices */
function testSetLut() {
	reds = Array.getSequence(256);
	greens = Array.getSequence(256);
	blues = newArray(256);
	setLut(reds, greens, blues);
}

/** 'imgID' the image to which add missing files informations
	'foldername' the path of input folder
	'missingFilenames' the array of names of missing images
	'missingChannels' the array from which get the channel of each missing image
	'missingTimepoints' the array from which get the frame of each missing image
	'seriesColors' channel colors array for imgID */
function addMissingFilesInfos(imgID, foldername, missingFilenames,
		missingChannels, missingTimepoints, seriesColors) {
	dbg=false;
	if (dbg) print("\naddMissingFilesInfos:");
	nfs = missingFilenames.length;
	ncs = missingChannels.length;
	nts = missingTimepoints.length;
	if (nfs!=ncs || ncs!=nts || nts!=nfs) return;
	if (dbg) print("nfs = "+nfs);
	id = getImageID();
	selectImage(imgID);
	Stack.getDimensions(width, height, chns, slices, frames);
	if (dbg) print("width = "+width+"  height = "+height);
	texts = newArray(5);
	texts[0] = "FILE NOT FOUND";
	texts[1] = "Input dir:";
	texts[2] = foldername;
	texts[3] = "Filename:";
	fontSize=12;
	maxTextWidth=0;
	setFont("SanSerif", fontSize, "bold antialiased");
	textWidths = newArray(5);
	for (i=0; i<nfs; i++) {
		chn = missingChannels[i]+1;
		tpoint = missingTimepoints[i];
		texts[4] = missingFilenames[i];
		textWidth = 0;
		for (k=0; k<texts.length; k++) {
			w = getStringWidth(texts[k]);
			if (w>maxTextWidth) maxTextWidth = w;
		}
	}
	fontSize *= width*0.98/maxTextWidth;
	fontSize = floor(fontSize);
	if (dbg) print("fontSize = "+fontSize);
	vGap = (height-fontSize)/5;
	setFont("SanSerif", fontSize, "bold antialiased");
	for (i=0; i<nfs; i++) {
		chn = missingChannels[i]+1;
		tpoint = missingTimepoints[i];
		texts[4] = missingFilenames[i];
		//ImageJ bug: roi width may be smaller or larger than text width 
		for (k=0; k<texts.length; k++) textWidths[k] = getStringWidth(texts[k]);
		for (k=0; k<texts.length; k++) {
			x=floor((width-textWidths[k])/2);
			if (x<1) x=1;
			y=(k+1/2)*vGap+fontSize;
			clr = seriesColors[chn-1];
			setColor(clr);
			Overlay.drawString(texts[k], x, y);
			Overlay.setPosition(chn, 0, tpoint);
			Overlay.show;//necessary to add text to Overlay!
		}
	}
	selectImage(id);
}

/** Returns LUT derived from 'illumSetting' got from Metadata.
	Used to assign channel color of images for which wavelength
	is not included in filenames. 
	Returned LUT is Red, Green or Blue.
	Returns Grays if cannot be determined */
function getLUT(illumSetting) {
	if (illumSetting=="" || illumSetting==0)
		return "Grays";
	//isDoubleIllumination = false;
	for (i=0; i<redDeterminants.length; i++)
		if (indexOf(illumSetting, redDeterminants[i])>=0)
			return "Red";
	for (i=0; i<greenDeterminants.length; i++)
		if (indexOf(illumSetting, greenDeterminants[i])>=0)
			return "Green";
	for (i=0; i<blueDeterminants.length; i++)
		if (indexOf(illumSetting, blueDeterminants[i])>=0)
			return "Blue";
	return "Grays";
}

function labelChannels(imageID, labels) {
	dbg = false;
	id = getImageID();
	selectImage(imageID);
	Stack.getDimensions(w, h, nchn, slices, frames);
	if (nchn<2) {
		selectImage(id);
		return;
	}
	if (nchn>labels.length) nchn = labels.length;
	for (c=0; c<nchn; c++) {
		if (dbg) print("labels["+c+"] = "+labels[c]);
		label = labels[c];
		if (dbg) print("label = "+label);
		for (z=1; z<=slices; z++) {
			for (t=1; t<=frames; t++) {
				Stack.setPosition(c+1, z, t);
				setMetadata("Label", label);
			}
		}
	}	
	selectImage(id);
}

function enhanceContrast(imgID, saturationsArray) {
	dbg = false;
	if (dbg) {
		print("Enhancing contrast:");
		for (c=0; c<saturationsArray.length; c++)
			print("saturationsArray["+c+"] = "+saturationsArray[c]);
	}
	id = getImageID();
	selectImage(imgID);
	Stack.getDimensions(width, height, nchn, slices, frames);
	if (slices>2) Stack.setSlice(slices/2);
	if (frames>2) Stack.setFrame(frames/2);
	for (c=0; c<nchn; c++) {
		if (saturationsArray[c]>0) {
			if (nchn>1) Stack.setChannel(c+1);
			saturated = saturationsArray[c];
			run("Enhance Contrast","saturated="+saturated);
		}
	}
	selectImage(id);
}

/* Transforms current image to a stack of 'nslices' copies */
function singleSectionToStack(nslices) {
	run("Select All"); run("Copy");
	for (i=1; i<nslices; i++) {run("Add Slice"); run("Paste");}
	run("Select None");
}

/** Extends current stack to 'nslices' by adding black slices
	Does nothing if stack-size >= 'nslices' */
function completeStackTo(nslices) {
	ns = nSlices();
	if (ns>=nslices) return;
	setSlice(ns);
	for (i=ns; i<=nslices-ns+1; i++) run("Add Slice");
}

function getImageType(bitdepth) {
	d = bitdepth;
	if (d==8) return "8-bit";
	else if (d==16) return "16-bit";
	else if (d==24) return "RGB Color";
	else if (d==32) return "32-bit";
	return "";
}

/* Returns false if none of projTypes has 32-bit result, true otherwise */
function needs32Bit(projTypes) {
	for (c=0; c<projTypes.length; c++) {
		if (projTypes[c]=="Sum Slices") return true;
		if (projTypes[c]=="Standard Deviation") return true;
		if (projTypes[c]=="Median") return true;
	}
	return false;
}

/* Returns seriesName.nd opened as a string */
function getNDContent(seriesName) {
	path = dir1+seriesName+".nd";
	if (!File.exists(path)) return "";
	return File.openAsString(path);
}

/** Returns positionName corresponding to positionString
	ndContent: nd file opened as a string
	positionString: "_s1", "_s2", "_s3", etc.
	positionName: "positionName1", "positionName2", "positionName3", etc
	if (positionString == "_s1") returns "positionName1" */
function getPositionNameFromNDContent(ndContent, positionString) {
	if (lengthOf(ndContent)==0) return positionString;
	if (!startsWith(ndContent, "\"NDInfoFile\"")) return positionString;
	lines = split(ndContent, "\n");
	if (lines.length==0) return positionString;
	//for (i=0; i<lines.length; i++) print("lines["+i+"] = "+lines[i]);
	i = parseInt(substring(positionString, 2, lengthOf(positionString)));
	posStrND = "\"Stage"+i+"\"";
	for (i=0; i<lines.length; i++) {
		line = lines[i];
		if (!startsWith(line, "\"Stage")) continue;
		toks = split(line, ",");
		if (toks[0]==posStrND) {
			print("\n"+toks[0]);
			posName = toks[1];
			posName = substring(posName, 2, lengthOf(posName)-1);
			posName = "_"+posName;
			posName = removeFilenamesForbiddenChars(positionString, posName);
			print(positionString+"  ===O==>  "+posName);
			return posName;
		}
	}
	return positionString;
}

/** Imports and scales image 'filename' using ImageJ's FileImporter 
	Speed depends perhaps on size of 'dir' (FileImporter analyzes
	the input folder prior to display user interface) */
function importAndScale(dir, filename, scaleFactor, startZ, stopZ) {
//slightly faster than open full size images and downsample afterwards ?
	run("Image Sequence...", "open=["+dir+filename+"]"+
		" number=1 scale="+scaleFactor*100+" file=["+filename+"] sort");
}

/* Resizes active image. Does nothing if 'scaleFactor' = 1. */
function resizeImage(scaleFactor) {
	if (scaleFactor==1) return;
	//print("scaleFactor = "+scaleFactor);
	w0 = getWidth; h0 = getHeight; d0 = nSlices;
	w0r = w0*scaleFactor;
	h0r = h0*scaleFactor;
	//print("w0="+w0+" h0="+h0);
	run("Size...", "width="+w0r+" height="+h0r+" depth="+d0+" average");
	//print("Resized width="+w0r+" height="+h0r);
}

/** Keeps slices from 'slice1' to 'slice2' included of active image stack
	if slice1 > slice2 resulting stack is reversed */
function keepSlices(slice1, slice2) {
	zSize = nSlices;
	if (slice1>zSize) {
		showMessage("extractSlices(slice1, slice2):"+
			"\nslice1 = "+slice1" > zSize = "+zSize);
		exit();
	}
	if (slice2>zSize) {
		showMessage("extractSlices(slice1, slice2):"+
			"\nslice2 = "+slice2" > zSize = "+zSize);
		exit();
	}
	if (zSize<2) return;
	if (slice1==1 && slice2==zSize) return;
	if (slice2==1 && slice1==zSize) {run("Reverse"); return;}
	if (slice1>slice2) {
		run("Reverse");
		keepSlices(zSize-slice1+1, zSize-slice2+1);
		return;
	}
	setSlice(zSize);
	for (s=zSize; s>slice2; s--) {
		if (nSlices>1)
		run("Delete Slice");
	}
	setSlice(1);
	for (s=1; s<slice1; s++) {
		if (nSlices>1)
		run("Delete Slice");
	}
}

/** Opens image stack 'path' from 'startZ' to 'stopZ'.
	'zFraction' = (stopZ-startZ)/numberOfPlanes, calculated before call
	if startZ > stopZ, stack is in reversed order */
function openZRange(path, zFraction, startZ, stopZ) {
	if (zFraction>0.15) {
		open(path);
		keepSlices(startZ, stopZ);
		return;
	}
	print("Open slice by slice: startSlice="+
			startSlice+" stopSlice="+stopSlice);
	//if zFraction<0.15, faster than open all slices and delete unwanted
	open(path, startSlice);
	if (stopSlice<startSlice) {
		for (s=startSlice-1; s>=stopSlice; s--) {
			IJ.redirectErrorMessages();
			print("s = "+s);
			open(path, s);
			run("Select All");
			run("Copy");
			close();
			run("Add Slice");
			run("Paste");
			run("Select None");
		}
	}
	else {
		for (s=startSlice+1; s<=stopSlice; s++) {
			IJ.redirectErrorMessages();
			print("s = "+s);
			open(path, s);
			run("Select All");
			run("Copy");
			close();
			run("Add Slice");
			run("Paste");
			run("Select None");
		}
	}
}

/** Gets series time interval in seconds if at least 2 timepoints are found
	for same channel.
	extensions: array specific of seriesIndex, same length as 'allChannels' */
function getFrameInterval(filenames, seriesIndex, extensions) {
	allChannels = toArray(seriesChannelSequences[seriesIndex],
			_2DarraysSplitter);
	nChannels = allChannels.length;
	msg = "Get time interval series ";
	print("\n"+msg+seriesIndex+" ("+seriesName+")");
	getMinAndMaxPosition(fnames, seriesIndex);
	print("minPosition="+minPosition+"  maxPosition="+maxPosition);
	nframesInChannels = getFrameNumbers(fnames, seriesIndex);
	print("nFrames="+nFrames);
//	ismultichannel = multichannelSeries[seriesIndex];
	for (j=minPosition; j<=maxPosition; j++) {
		pStr = "";
		if (multipositionSeries[seriesIndex]) pStr = "_s"+j;
		for (c=0; c<nChannels; c++) {
			if (nframesInChannels[c] < nFrames) continue;
			str2 = allChannels[c];
			ext = extensions[c];
			str = seriesName+str2+pStr;
			tini=1;
			//frames 1 and nFrames may be single plane
			if (nFrames>3) tini++;
			print("tini = "+tini);
			tend=nFrames;
			if (nFrames>4) tend--;
			print("tend = "+tend);
			tStr = "_t"+tini;
			fnameini = str+tStr+ext;
			print("Search 1st existing tpoint >= tini");
			while (!File.exists(dir1+fnameini)) {
				tStr = "_t"+ tini;
				fnameini = str+tStr+ext;
				if (File.exists(dir1+fnameini)) break;
				if (dbg) {print("tini = "+tini); print(fnameini);}
				tini++;
				if (tini==tend) break;
			}
			print("tini = "+tini);
			if (tini==tend) continue;
			print("fnameini = "+fnameini);
			print("Search last existing tpoint <= tend");
			tStr = "_t"+tend;
			fnameend = str+tStr+ext;
			print(fnameend);
			while (!File.exists(dir1+fnameend)) {
				tStr = "_t"+ tend;
				fnameend = str+tStr+ext;
				if (File.exists(dir1+fnameend)) break;
				if (dbg) {print("tend = "+tend); print(fnameend);}
				tend--;
				if (tend==tini) break;
			}
			print("tend = "+tend);
			print("tend-tini = "+(tend-tini));
			if ((tend-tini)<1) continue;
			sampleNames = newArray(fnameini,fnameend);
			acquisitionYears=newArray(2); acquisitionMonths=newArray(2);
			acquisitionDays=newArray(2); acquisitionTimes=newArray(2);
			foundAcquisitionTimes=newArray(2);
			id=0;
			for (s=0; s<=1; s++) {
				getAcquisitionTimeStr(dir1+sampleNames[s], id);
				computeAcquisitionDayAndTime(acquisitionTimeStr);
				print("acquisitionTimeStr = "+acquisitionTimeStr);
				if (dbg) print("acquisitionTime = "+acquisitionTime);
				if (acquisitionTimeStr!="") {
					acquisitionYears[s]=acquisitionYear;
					acquisitionMonths[s]=acquisitionMonth;
					acquisitionDays[s]=acquisitionDay;
					acquisitionTimes[s]=acquisitionTime;
					foundAcquisitionTimes[s] = true;
				}
			}
			if (foundAcquisitionTimes[0] && foundAcquisitionTimes[1]) {
				dt = computeTimelapseDuration(acquisitionYears,
					acquisitionMonths,acquisitionDays,acquisitionTimes);
				print("dt="+dt);
				if (dt>0) {
					timeUnit="s";
					frameInterval = dt/(tend-tini);
					frameInterval /= 1000;
				}
			}
			c = nChannels-1;//exit channels loop
			j = maxPosition;//exit positions loop
			break;
		}
	}
	print("frameInterval = "+frameInterval+" "+timeUnit);
	print("End "+msg+seriesIndex+" ("+seriesName+")");
}//getFrameInterval()

/** Gets spatial calibration of series[seriesIndex'] 
	Assumes all images have same bit-depths and xy sizes.
	multi-wavelength: all channels are checked
	multi-position: 1st found position is checked
	time-series: checks 3 timepoints */
function getSpatialCalibration(seriesIndex, channels) {
	nChannels = channels.length;
	seriesName = seriesNames[seriesIndex];
	msg = " spatial calibration of series ";
	print("\nGet"+msg+seriesIndex+" ("+seriesName+")");
	print("multichannelSeries["+seriesIndex+"] = "+
			multichannelSeries[seriesIndex]);//false if extract 1 channel from
			//multiChannel series
	for (c=0; c<nChannels; c++) print("channels["+c+"] = "+channels[c]);
	dbg=false;
	dbg2 = false;
	if (File.exists(dir1+seriesName))
		nTimepoints = getNTimePointsFromND(list, seriesIndex);
	else
		nTimepoints = getFramesNumber(list, seriesName);
	nframesInChannels = getFrameNumbers(fnames, seriesIndex);
	nchn = channels.length;
	if (dbg) {
		for (c=0; c<nChannels; c++)
			print(channels[c]+": "+nframesInChannels[c]+" timepoints");
	}
	print("nChannels="+nChannels);
	ismultiposition = multipositionSeries[i];
	print("nTimepoints="+nTimepoints);
	positionStr = "";
	npositions = positionNumbers[seriesIndex];
	if (dbg) print("positionNumbers["+seriesIndex+"]="+npositions);
	if (dbg2) for (q=0; q<positionNumbers.length; q++)
		print("positionNumbers["+q+"] = "+positionNumbers[q]);
	if (dbg2) for (p=0; p<positionsSeriesBySeries.length; p++)
		print("positionsSeriesBySeries["+p+"] = "+positionsSeriesBySeries[p]);
	p=0; for (q=0; q<seriesIndex; q++) p += positionNumbers[q];
	if (dbg) print("Position start index : p = "+ p);
	maxlength = 0;
	fname = "";
	if (dbg) {
		print("nFrames="+nFrames);print("startT="+startT+" stopT="+stopT);
	}
	foundCalibrationImage = false;
	for (t=2; t<nFrames; t++) {//possible problem if files are missing
		//don't use first and last frames which may be single slice images
		//possible problem if a channel is acquired only at t=1 and t=nFrames
		tStr = "";
		if (istimeseries) tStr = "_t" + 2;
		if (dbg2) print("positionNumbers["+seriesIndex+"]="+npositions);
		for (s=p; s<p+npositions; s++) {
			if (dbg) print("position index s = "+ s);
			if (positionsSeriesBySeries[s]==0) continue;
			if (ismultiposition && positionsSeriesBySeries[s]=="") continue;
			if (!positionExists[s]) continue;
/*
			if (!isCompletePosition[s]) //NEVER TRUE
				continue;
*/
			positionStr = positionsSeriesBySeries[s];
			if (multichannelSeries[seriesIndex]) {
				for (c=0; c<nChannels; c++) {
					wStr = channels[c];//= "" if !multichannelSeries[i]
					if (dbg) print("wStr = "+wStr);
					if (dbg) print("positionStr = "+positionStr);
					if (dbg) print("tStr = "+tStr);
					name = seriesName+wStr+positionStr+tStr+extensions[c];
					if (dbg) print("Channel loop: name = "+name);
					if (name=="") continue;
					if (name==0) continue;
					path = dir1+name;
					if (!File.exists(path)) continue;
					length = File.length(path);
					if (dbg) print("length = "+length);
				//	select the biggest image file of all channels to ensure it's
				//	a z-stack (user may not have done z-stack for all channels)
					if (nChannels==1 || c>0 && length>maxlength*1.5) {
						//condition may not work
						maxlength = length;
						fname = name;
						foundCalibrationImage = true;
						break;
					}
				}//channels c
			}
			else {
				wStr = "";//marche pas si juste un canal extrait de multiChannel
				wStr = channels[0];//OK
				name = seriesName+wStr+positionStr+tStr+extensions[0];
				path = dir1+name;
				if (File.exists(path)) {
					fname = name;
					foundCalibrationImage = true;
					//break;
				}
			}
			if (foundCalibrationImage) break;
			print("getSpatialCalibration(): cannot find file:\n"+name);
			print("Searching another file for calibration");
		}//positions s
		if (dbg) print("position index s = "+ s);
		if (foundCalibrationImage) break;
	}//timepoints t
	if (dbg) print("fname = "+fname);
	if (foundCalibrationImage)
		print("Found following calibration source: "+fname);
	path = dir1+fname;
	//print("getImageMetadata from:\n"+path);
	id=0; use_tiff_tags_plugin = true;
	voxelWidth = 1;
	voxelHeight = 1;
	voxelDepth = 1;
	xyUnit = "pixel";
	if (getImageMetadata(path, id, use_tiff_tags_plugin)) {
		voxelWidth = xCalibration;
		voxelHeight = yCalibration;
		xyUnit = spatialCalibrationIUnit;
		if (xyUnit=="um") xyUnit = "micron";
		voxelDepth = computeZInterval();
		foundZInterval = true;
	}
	print("isSpatiallyCalibrated = "+isSpatiallyCalibrated);
	print("voxelWidth = "+voxelWidth);			
	print("voxelDepth = "+voxelDepth);			
	print("xyzUnit = "+xyUnit);			
	if (numberOfPlanes==0) {
//		get_imagesType_maxWidth_maxHeight_maxDepth(seriesName);//done in caller
		print("maxImageDepth = "+maxImageDepth);			
		print("numberOfPlanes from maxImageDepth of series = "+maxImageDepth);
		numberOfPlanes = maxImageDepth;
	}
	if (fname=="") {
		print("getSpatialCalibration(): cannot find file:\n"+fname);
		print("xyz calibration may be wrong");
	}
	if (numberOfPlanes==0 && fname!="" && File.exists(path)) {
		print("\n \n \n"+path+"\n \n \n ");
		open(path);
		numberOfPlanes = nSlices();
		close();
		print("Opening image to get numberOfPlanes: "+numberOfPlanes);
	}
	print("numberOfPlanes = "+numberOfPlanes);
	print("End"+msg+seriesIndex+" ("+seriesName+")\n ");
}

/** Returns number of timepoints in series number 'seriesIndex'
	Returns 1 if the series is not a time-series.
	Needs ND file. Returns -1 if ND file not found */
function getNTimePointsFromND(files, seriesIndex) {
	dbg=true;
	if (dbg) {
		print("getNTimePointsFromND(files, seriesIndex) Series "+
			seriesIndex+" ("+seriesName+")");
	}
	timepoints = 1;
	seriesName = seriesNames[seriesIndex];
	if (!isTimeSeries(files, seriesName)) {
		if (dbg) print("Not a time series : nTimepoints = 1");
		return 1;
	}
	if (!File.exists(dir1+seriesName+".nd")) {
		return-1;
	}
	if (getParamsFromND(seriesName)) {
		if (dbg) print("nTimepoints from ND = "+nTimepoints);
		return NTimePoints;
	}
}

function processFolder() {
	print(separationLine);
	print("\nprocessFolder()");
	dbg=false;
	setBatchMode(true);
	logCount = 0;
	List.clear();
	filterExtensions = isExtensionFilter(fileFilter);
	print("filterExtensions="+filterExtensions);
	nSeries = seriesNames.length;
	print("processFolder(): nSeries="+nSeries);
	for (i=0; i<seriesNames.length; i++)
		print("seriesNames["+i+"]="+seriesNames[i]);
	for (i=0; i<doSeries.length; i++) print("doSeries["+i+"]="+doSeries[i]);
	fF = fileFilter;
	positionIndex3 = 0;
	for (i=0; i<seriesNames.length; i++) {
		print("\n");
		initializeMetadata();
		voxelDepth = userVoxelDepth;
		foundZInterval = false;
		//print("\ndoSeries["+i+"]="+doSeries[i]);
		if (!doSeries[i]) {
			positionIndex3 += positionNumbers[i];
			continue;
		}
		pixelSize = 1;
		xyUnit = "pixel";
		isSpatiallyCalibrated = false;
		seriesName = seriesNames[i];
		print("Processing "+seriesName);
		if (!File.exists(dir1+seriesName+".nd")) {
			print("Found no ND file for this series.\nProcessing may fail "+
			"or result in errors in output images");
		}
		get_imagesType_maxWidth_maxHeight_maxDepth(seriesName);
		//-> imagesType, maxImageWidth, maxImageHeight, maxImageDepth
		type = imagesType;
		if (maxImageWidth==0 || maxImageHeight==0) {
			print("Error in determining series max image width"+
					" and height: skipped");
			positionIndex3 += positionNumbers[i];
			continue;
		}
		fnames = split(seriesFilenamesStr[i], _2DarraysSplitter);
		print("i = "+i+"  seriesFilenamesStr[i] = "+seriesFilenamesStr[i]);
		print("fnames:");
		for (q=0; q<fnames.length; q++) print(fnames[q]);
		nFilesInSeries = seriesFileNumbers[i];
		if (dbg) print("nFilesInSeries="+nFilesInSeries);
		channelGroupIndex = seriesChannelGroups[i];// ?
		if (true) print("channelGroupIndex="+channelGroupIndex);
		doChannels = toArray(doChannelsFromSequences[channelGroupIndex],
				_2DarraysSplitter);
		if (true) for (k=0; k<doChannels.length; k++) {
			print("doChannels["+k+"]="+doChannels[k]);
		}
		nChannels=0;
		for (k=0; k<doChannels.length; k++) {
			if (doChannels[k]) nChannels++;
		}
		print("nChannels="+nChannels);
		allChannels = toArray(seriesChannelSequences[i], _2DarraysSplitter);
		for (k=0; k<allChannels.length; k++) {
			if (allChannels[k]==0) allChannels[k]="";
			print("allChannels["+k+"]="+allChannels[k]);
		}
		chnColors = toArray(
			channelSequencesColors[channelGroupIndex], _2DarraysSplitter);
		chnSaturations = toArray(
			channelSequencesSaturations[channelGroupIndex], _2DarraysSplitter);
		for (k=0; k<chnSaturations.length; k++) {
			print("chnSaturations["+k+"]="+chnSaturations[k]);
		}
		for (k=0; k<chnColors.length; k++) {
			print("chnColors["+k+"]="+chnColors[k]);
		}
		//channels, seriesColors, saturations... must be reduced to 
		//elements for which doChannels = true
		channels = newArray(nChannels);
		seriesColors = newArray(nChannels);
		saturations = newArray(nChannels);
		k=0;
		for (c=0; c<allChannels.length; c++) {
			if (doChannels[c]) {
				channels[k] = allChannels[c];
				seriesColors[k] = chnColors[c];
				saturations[k] = chnSaturations[c];
				k++;
			}
		}
		for (k=0; k<nChannels; k++) {//ok even if 1st channels ignored
			print("channels["+k+"]="+channels[k]);
			print("seriesColors["+k+"]="+seriesColors[k]);
			print("saturations["+k+"]="+saturations[k]);
		}
		channelColorIndexes = computeColorIndexes(channels, seriesColors);
		compositeStrs = newArray(nChannels);//ancien
		//compositeStrs = newArray(allChannels.length);
		if (dbg)
			print("channelColorIndexes.length = "+channelColorIndexes.length);
		if (dbg) print("Channels to do:");
		if (true) for (k=0; k<channels.length; k++) {
			//print("channels["+k+"] = "+channels[k]);
			print("channelColorIndexes["+k+"]="+channelColorIndexes[k]);
		}
		if (dbg) print("seriesColors.length="+seriesColors.length);
		print("Channel colors:");
		for (k=0; k<channels.length; k++) {
//			print(usedChannels[k] + " : "+
//					compositeChannels[channelColorIndexes[k]]);
			//print(allChannels[k] + " : "+colors[channelColorIndexes[k]]);
			print(channels[k] + " : "+colors[channelColorIndexes[k]]);
			print("saturations["+k+"]="+saturations[k]);
		}
		for (k=0; k<channels.length; k++) {
		//for (k=0; k<allChannels.length; k++) {
			compositeStrs[k]=compositeChannels[channelColorIndexes[k]];
			print("compositeStrs["+k+"] = "+compositeStrs[k]);
		}
		//to be merged, channels must be reordered by increasing c numbers
		//reorderedChannels = strings array
		reorderedChannels = reorderArray(channels, channels, compositeStrs);
		reorderedCompositeStrs = reorderArray(
								compositeStrs, channels, compositeStrs);
		seriesColors = reorderArray(seriesColors, channels, compositeStrs);
		saturations = reorderArray(saturations, channels, compositeStrs);

		//Debug of wrong projection types
		reorderedChannelIndexes = newArray(channels.length);
		for (k=0; k<channels.length; k++) {
			for (k2=0; k2<channels.length; k2++) {
				if (reorderedChannels[k2]==channels[k]) {
					reorderedChannelIndexes[k] = k2;
					break;
				}
			}
		}
		//POSSIBLE BUG
/*
		//if (active, projection-types etc not assigned to right channels)
		channelColorIndexes = computeColorIndexes(
				reorderedChannels, seriesColors);
*/
		channelColorIndexes =
			ensureColorIndexesAreDifferent(channelColorIndexes);
		for (k=0; k<nChannels; k++) {//seems ok
			print("channels["+k+"] = "+channels[k]);
			print("channelColorIndexes["+k+"] = "+channelColorIndexes[k]);
			print("reorderedChannels["+k+"] = "+reorderedChannels[k]);
			print("reorderedCompositeStrs["+k+"] = "+reorderedCompositeStrs[k]);
			print("seriesColors["+k+"] = "+seriesColors[k]);
			print("saturations["+k+"] = "+saturations[k]);
		}
		extensions = getExtensions(fnames, seriesName);
		if (dbg) for (k=0; k<extensions.length; k++)
			print("extensions["+k+"] = "+extensions[k]);
		ismultiposition = multipositionSeries[i];
		if (ismultiposition) print("isMultiposition = true");
		nPositions = positionNumbers[i];
		print("nPositions="+nPositions);
		istimeseries = timeSeries[i];
		if (istimeseries) print("istimeSeries = true");
		else print("istimeSeries = false");
		//if (isTimeFilter(fF)) istimeseries = false;
		//	print("istimeSeries = false");
		nFrames = getFramesNumber(fnames, seriesName);
		nframesInChannels = getFrameNumbers(fnames, i);
		print("nFrames="+nFrames);
		wStr = ""; pStr = ""; tStr = "";
		frameInterval = userFrameInterval;
		timeUnit = userTimeUnit;
		if (istimeseries) {
			acquisitionYears = newArray(2); acquisitionMonths = newArray(2);
			acquisitionDays = newArray(2); acquisitionTimes = newArray(2);
		}
		doZprojs = doZprojForChannelSequences[channelGroupIndex];
		//POSSIBLE BUG
		projTypes = toArray(projTypesForChannelSequences[channelGroupIndex],
					_2DarraysSplitter);
		for (k=0; k<projTypes.length; k++) {
			print("projTypes["+k+"]="+projTypes[k]);
			print("channelColorIndexes["+k+"]="+channelColorIndexes[k]);
			print("reorderedChannels["+k+"]="+reorderedChannels[k]);
		}
		if (doZprojs) to32Bit = needs32Bit(projTypes);
		print("to32Bit="+to32Bit);
		startT = firstTimePoint;
		if (lastTimePoint==-1) stopT = nFrames;
		else stopT = lastTimePoint;
		if (doRangeFrom_t1) stopT = round(nFrames*rangeFrom_t1 / 100);
		if (startT<1) startT = 1;
		if (stopT>nFrames) stopT = nFrames;
		if (stopT<startT) stopT = startT;
		if (stopT==-1) stopT = nFrames;
		if (startT>stopT) startT = stopT;
		print("startT="+startT+"  stopT="+stopT);
		timeRange = stopT - startT;
		if (dbg) print("timeRange="+timeRange);
		if (dbg) for (j=0; j<userPositionsSeriesBySeries.length; j++) {
			print("positionExists["+j+"]="+positionExists[j]);
			print("userPositionsSeriesBySeries["+j+"]="
				+userPositionsSeriesBySeries[j]);
		}
		getSpatialCalibration(i, allChannels);
		if (numberOfPlanes==0) numberOfPlanes = maxImageDepth;
		if (numberOfPlanes==0) numberOfPlanes = 1;
		if (isSpatiallyCalibrated) {
			if (dbg) print("voxelWidth="+voxelWidth+
					"  voxelDepth="+voxelDepth+"  xyUnit="+xyUnit);
			if (xyUnit!=userLengthUnit) {
				voxelDepth = recalculateVoxelDepth(voxelDepth,
					userLengthUnit, xyUnit);
			}
			if (resize && resizeFactor!=1) {
				voxelWidth /= resizeFactor;
				voxelHeight /= resizeFactor;
			}
			if (doPixelSizeCorrection && pixelSizeCorrection!=1) {
				voxelWidth *= pixelSizeCorrection;
				voxelHeight *= pixelSizeCorrection;
			}
		}
		if (!useUserTimeCalibration && istimeseries && nFrames>1) {
			getFrameInterval(fnames, i, extensions);
		}
		positionIndex2 = 0;
		if (dbg) print("\npositionIndex3 = "+positionIndex3);
		pp = 0;
		if (positionNamesFromND) ndContent = getNDContent(seriesName);
		for (j=positionIndex3; j<positionIndex3+positionNumbers[i]; j++) {
			if (dbg) print("userPositionsSeriesBySeries["+j+"] = "+
					userPositionsSeriesBySeries[j]);
			positionIndex2++;
			if (!positionExists[j] || userPositionsSeriesBySeries[j]==0) {
				continue;
			}
			//if (!isCompletePosition[j]) continue;//problem
			if (positionIndex2==(positionNumbers[i])+1) break;
			pStr2 = "";
			if (ismultiposition) {
				pStr = userPositionsSeriesBySeries[j];
				pStr2 = pStr;
				if (positionNamesFromND)
					pStr2 = getPositionNameFromNDContent(ndContent, pStr);
				//if-block behaviour depends on operands order!
				//if (!isUserPosition || isPositionFilter(fF)
				if (isPositionFilter(fF) && indexOf(pStr+"_", fF)<0
						&& indexOf(pStr+".", fF)<0) {
					print("Position "+p+" skipped");
					continue;
				}
				else
					pp++;
				print("\nProcessing position "+userPositionsSeriesBySeries[j]);
				//print("Processing position "+p); print("pp = "+pp);
			}
			nRois = 1;
			if (crop) {
				getRoisFromImage(prefixLessRoiImages, seriesName, channels,
						userPositionsSeriesBySeries[j]);
				nRois = roiManager("count");
			}
			for (r=0; r<nRois; r++) {
			//contenu boucle sur r devrait etre decale d'un tab a droite
			print("Processing Roi "+r);
			//opens all 'c' and 't' images for each roi & crops.
			//rois loop (r) ends just before positions loop (j)
			//processFolder2() opens each image once and duplicates
			//content of roi.
			nslices = 1;
			tpoints = stopT-startT+1;
			expectedNFiles = nChannels*tpoints;
			missingFilenames = newArray(expectedNFiles);
			missingChannels = newArray(expectedNFiles);
			missingTimepoints = newArray(expectedNFiles);
			missingFileIndex = 0;
			if (istimeseries) {
				print("startT="+startT+"  stopT="+stopT);
				print("Processing "+tpoints+" timepoints:");
			}
			tt = 0;
			for (t=startT; t<=stopT; t++) {
				if (istimeseries) {
					print("t"+t);
					tStr = "_t"+t;
					if (isTimeFilter(fF) &&
							indexOf(tStr+"_", fF)<0 &&
							indexOf(tStr+".", fF)<0) {
						print("skip timepoint "+t);
						continue;
					}
					else
						tt++;
				}
				channelsStr = "";
				nimg=0;//local channel counter for RGB merge
				depths = newArray(nChannels);
				imgIDs = newArray(nChannels);
				maxDepth = 1;
				for (c=0; c<nChannels; c++) {
					//if (nChannels>1) {
						wStr = reorderedChannels[c];//permute canaux
						//wStr = channels[c];//decale w2 en w1 si w1 decoche
						//print("reorderedChannels["+c+"] = "+
						//		reorderedChannels[c]);
						if (isWaveFilter(fF) && indexOf(wStr, fF)<0) {
							continue;
						}
						if (timeRange>0 && nframesInChannels[c]==1 &&
								ignoreSingleTimepointChannels) {
							nChannels--;
							continue;
						}
					//}
					if (extensions[c]==0) extensions[c]="";
					fn = seriesName+wStr+pStr+tStr+extensions[c];
					if (dbg) {
						print("seriesName = "+seriesName); print("wStr = "+wStr);
						print("pStr = "+pStr); print("pStr2 = "+pStr2);
						print("tStr = "+tStr);
						print("extensions[c] = "+extensions[c]);
						print("fn = "+fn);
					}
					path = dir1+fn;
					if (dbg) print(""+fn);
					doResize = false;
					startSlice = 1;
					stopSlice = numberOfPlanes;
					if (!File.exists(path)) {
						missingFilenames[missingFileIndex] = fn;
						missingChannels[missingFileIndex] = c;
						missingTimepoints[missingFileIndex] = tt;//t ?
						missingFileIndex++;
						print("Cannot find file\n"+dir1+"\n"+fn);
						print("Replacing with black");
						ww = maxImageWidth;
						hh = maxImageHeight;
						dd = maxImageDepth;//POSSIBLE PROBLRM
						//dd = slices;//PROBLEM
						if (doZprojs) dd = 1;
						if (to32Bit) type = "32-bit";
						if (dbg) print("type="+type+" width="+ww+" height="+hh+
								" depth="+dd);
						newImage("Black", type+" black", ww, hh, dd);
					}
					else {
						if (dbg) print("numberOfPlanes = "+numberOfPlanes);
						if (dbg) print("firstSlice = "+firstSlice+
								"  lastSlice = "+lastSlice);
						if (doRangeAroundMedianSlice) {
							startSlice = numberOfPlanes/2 * 
								(1 - rangeAroundMedianSlice/100);
							stopSlice = numberOfPlanes/2 *
								(1 + rangeAroundMedianSlice/100);
							startSlice = floor(startSlice)-1;
							stopSlice = floor(stopSlice)-1;
						}
						else {
							if (firstSlice<=0)
								startSlice = numberOfPlanes;
							else
								startSlice = firstSlice;
							if (lastSlice<=0)
								stopSlice = numberOfPlanes;
							else
								stopSlice = lastSlice;
						}
						if (dbg) print("startSlice="+startSlice+
								" stopSlice="+stopSlice);
						if (startSlice<1)
							startSlice = 1;
						if (startSlice>numberOfPlanes)
							startSlice = numberOfPlanes;
						if (stopSlice<1)
							stopSlice = 1;
						if (stopSlice>numberOfPlanes)
							stopSlice = numberOfPlanes;
						slices = abs(stopSlice - startSlice) + 1;
						//if resize, faster than open and resize
						//importAndScale(path, scaleFactor)
						if (slices==numberOfPlanes) {
							open(path);
							if (startSlice==numberOfPlanes &&
									numberOfPlanes>1 && !doZprojs)
								run("Reverse");
						}
						else {
							openZRange(path, rangeAroundMedianSlice/100,
									startSlice, stopSlice);
						}
						currentWidth = getWidth();
						currentHeight = getHeight();
						currentDepth = nSlices;
						maxWidth = maxImageWidth;
						maxHeight = maxImageHeight;
						doResize = false;
						if (currentWidth!=maxWidth ||
								currentHeight!=maxHeight) {
							doResize = true;
							if (dbg) {
								print("currentWidth = "+currentWidth);
								print("currentHeight = "+currentHeight);
								print("currentDepth = "+currentDepth);
								print("maxWidth = "+maxWidth);
								print("maxHeight = "+maxHeight);
							}
							print("Resizing image");
							run("Size...", "width="+maxWidth+" height="+
								maxHeight+" depth="+nSlices+
								" average interpolation=None");
						}
					}
					if (crop && roiManager("count")>0) {
						roiManager("select", r);
						Stack.getDimensions(width, height,
											nchannels, depth, nframes);
						Roi.getBounds(roiX, roiY, roiW, roiH);
						if (roiW*roiH>0 && (roiW<width || roiH<height)) {
							makeRectangle(roiX, roiY, roiW, roiH);
							run("Crop");
						}
						roiManager("deselect");
					}
					if (resize && resizeFactor!=1)
						resizeImage(resizeFactor);
					//print("nImages-nImages0 = "+(nImages-nImages0));
					if (nImages-nImages0==0) break;
					nimg++;
					bitdepth = bitDepth();
					type = getImageType(bitdepth);
					Stack.getDimensions(w, h, nchn, nslices, frames);
					if (nslices>maxDepth) maxDepth = nslices;
					depths[c] = nslices;
					ID = getImageID();
					//binning may depend on channel (seems managed by Metamorph)
					//print("i="+i+" j="+j+" t="+t+" c="+c);
					//print("pp = "+pp);
					if (doZprojs && nslices>1) {
			//			print("Image: "+getTitle());
/*
						print ("c = "+c+" : projection=["+
								projTypes[reorderedChannelIndexes[c]]+"]");
*/
						run("Z Project...", "projection=["+
								projTypes[reorderedChannelIndexes[c]]+"]");
/*
						//wrong projection types (permutated)
						print("Image: "+getTitle());
						print ("c = "+c+" : projection=["+projTypes[c]+"]");
						run("Z Project...", "projection=["+projTypes[c]+"]");
*/
						if (to32Bit) run("32-bit");
						nslices = 1;
						projID = getImageID();
						selectImage(ID);
						if(nImages-nImages0>0) close();
						selectImage(projID);
					}
					imgIDs[c] = getImageID();
					chnname = reorderedCompositeStrs[c];
					rename(chnname);
					channelsStr += chnname+"="+chnname+" ";
				}
				if (nimg==0) continue;
				//print("doZprojs = "+doZprojs);
				//print("maxDepth = "+maxDepth);
				if (!doZprojs && maxDepth>1) {
					heterogeneousZDims = false;
					for (q=0; q<depths.length; q++) {
						//print("depths[q] = "+depths[q]);
						for (d=q+1; d<depths.length; d++) {
							if (depths[d] != depths[q]) {
								heterogeneousZDims = true;
								break;
							}
						}
					}
					if (heterogeneousZDims) {
						for (q=0; q<depths.length; q++) {
							if (depths[q]<maxDepth && depths[q]>1) {
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
				if (dbg) print("nimg = "+nimg);
				if (nimg>1) {
					if (dbg) print("channelsStr = "+channelsStr);
					//binning may depend on channel (seems managed in MM)
					IJ.redirectErrorMessages();
					run("Merge Channels...", channelsStr+" create");
					//--> CZ hyperstack
					//saveAs("tif", dir2+"Mergedchannels.tif");
					//nimg--;
					nimg -= nChannels - 1;
				}
				else {
					if (dbg) print("c="+c+" cc="+cc);
					//mettre la couleur du canal
					//run(colors[channelColorIndexes[cc]]);
					//marche pas ou defait + loin
				}
				rename("t"+t);
				if (istimeseries && timeRange>0) {
					//print("t = "+t);
					//print("tt = "+tt);
					if (tt==2)
						run("Concatenate...",
							"open image1=t"+startT+" image2=t"+(startT+1));
					if (tt>2)
						run("Concatenate...",
							"open image1=Untitled image2=t"+t);
				}
				if (nImages-nImages0==0) continue;
			}//time t
			if (nImages-nImages0==0) continue;
			getDimensions(ww, hh, nch, ns, nf);
			if (ns<2) voxelDepth = 0;
			//print("isSpatiallyCalibrated = "+isSpatiallyCalibrated);
			if (isSpatiallyCalibrated && !useUserXYZCalibrations)
				setVoxelSize(voxelWidth, voxelHeight, voxelDepth, xyUnit);
			else {
				setVoxelSize(userPixelSize, userPixelSize,
					voxelDepth, userLengthUnit);
			}
/*
			if (useUserXYZCalibrations) setVoxelSize(userPixelSize,
					userPixelSize, voxelDepth, userLengthUnit);
*/
			if (dbg) print("lastTimePoint="+lastTimePoint+
					"  firstTimePoint="+firstTimePoint);
			if (istimeseries) {
				//print("usedChannels.length = "+usedChannels.length);
				//Stack.setDimensions(usedChannels.length,nslices,nFrames);
				//print("nChannels="+nChannels);
				if (nChannels*nslices*timeRange>1)
					Stack.setDimensions(nChannels, nslices, timeRange+1);
				Stack.setTUnit(timeUnit);
				Stack.setFrameInterval(frameInterval);
			}
			//rename(seriesNames[i]+"_s"+p);
			rename(seriesName+userPositionsSeriesBySeries[j]);
			if (isTimeFilter(fF)) {
				//Stack.setDimensions(usedChannels.length, nslices, 1);
				Stack.setDimensions(nChannels, nslices, 1);
				//Stack.setDimensions(allChannels.length, nslices, 1);
			}
			id = getImageID();
			//labelChannels(id, usedChannels);
			//labelChannels(id, channels);
			labelChannels(id, reorderedChannels);//ok
			id = getImageID();
			enhanceContrast(id, saturations);//ok
			Stack.getDimensions(w, h, nch, slices, frames);
			if (type!="RGB"&& nch==1 && channels[0]=="") {//possible problem
			//if (nch==1) {
				//print("run("+colors[channelColorIndexes[0]]+")");
				//run(colors[channelColorIndexes[0]]);//obsolete
				//getLUT(illumSetting) finds LUT if wavelength not in filename
				lutName = getLUT(illumSetting);
				run(lutName);
				//if (allChannels[0]=="Undefined_Channel") run("Grays");
				if (channels[0]=="") run("Grays");
			}
			setMetadata("Info", info);
			outname = seriesName+pStr2;
			outdirSuffix = outname;
			if (crop)
				outname = outname + "_x"+roiX+"y"+roiY;
			if (resize && resizeFactor!=1)
				outname = outname + "_resize"+resizeFactor;
			print("startSlice="+startSlice+" stopSlice="+stopSlice);
			print("numberOfPlanes = "+numberOfPlanes);
			if (startSlice!=1 || stopSlice!=numberOfPlanes)
				outname = outname + "_z"+startSlice+"-"+stopSlice;
			if (istimeseries && startT!=1 && stopT!=nFrames)
				if (startT!=1 || stopT!=lastTimePoint)
					outname = outname + "_t"+startT+"-"+stopT;
			outdir = dir2;
			if (istimeseries && isTimeFilter(fF)) {
				outname = outname + tStr;
				outdirSuffix = outdirSuffix + tStr;
			}
			missingFilenames = Array.trim(missingFilenames, missingFileIndex);
			missingChannels = Array.trim(missingChannels, missingFileIndex);
			missingTimepoints = Array.trim(missingTimepoints, missingFileIndex);
			imgID = getImageID();
			if (missingFilenames.length>0)
				addMissingFilesInfos(imgID, dir1,
						missingFilenames, missingChannels,
						missingTimepoints, seriesColors);
			print("Save "+outname+".tif");
			saveAs("tiff", outdir+outname+".tif");
			print("");
/*
			if (istimeseries && isTimeFilter(fF))
				saveAs("tiff", dir2+seriesName+pStr2+tStr+".tif");
			else
				saveAs("tiff", dir2+seriesName+pStr2+".tif");
*/
			close();
			while (nImages>nImages0) close();
			saveLog(logCount++);
			}//roi r
			if (crop) roiManager("reset");
		}//position j
		positionIndex3 += positionNumbers[i];
		printMetadata();
	}//series i
	setBatchMode(false);
}//processFolder()

function processFolder2() {
	print(separationLine);
	print("\nprocessFolder2()");
	dbg = false;
	setBatchMode(true);
	List.clear();
	logCount = 0;
	filterExtensions = isExtensionFilter(fileFilter);
	print("filterExtensions="+filterExtensions);
	nSeries = seriesNames.length;
	print("processFolder2(): nSeries="+nSeries);
	ismultiposition = false;
	istimeseries = false;
	nChannels = 1;
	nPositions = 1;
	nFrames = 1;
	//print("\nseriesNames:");
	//for (i=0; i<seriesNames.length; i++) print(seriesNames[i]);
	for (i=0; i<doSeries.length; i++) print("doSeries["+i+"]="+doSeries[i]);
	print("\nProcessing series:");
	fF = fileFilter;
	positionIndex3 = 0;
	for (i=0; i<nSeries; i++) {
		print("");
		initializeMetadata();
		voxelDepth = userVoxelDepth;
		foundZInterval = false;
		if (!doSeries[i]) {
			positionIndex3 += positionNumbers[i];
			continue;
		}
		pixelSize = 1;
		xyUnit = "pixel";
		isSpatiallyCalibrated = false;
		seriesName = seriesNames[i];
		print("\nProcessing "+seriesName + ":");
		get_imagesType_maxWidth_maxHeight_maxDepth(seriesName);
		type = imagesType;
		if (maxImageWidth==0 || maxImageHeight==0) {
			print("Error in determining series max image width"+
					" and height: skipped");
			positionIndex3 += positionNumbers[i];
			continue;
		}
		fnames = split(seriesFilenamesStr[i], _2DarraysSplitter);
		nFilesInSeries = seriesFileNumbers[i];
		if (dbg) print("nFilesInSeries="+nFilesInSeries);
		channelGroupIndex = seriesChannelGroups[i];//FAUX
		if (true) print("channelGroupIndex = "+channelGroupIndex);
		doChannels = toArray(doChannelsFromSequences[channelGroupIndex],
				_2DarraysSplitter);
		if (true) for (k=0; k<doChannels.length; k++) {
			print("doChannels["+k+"]="+doChannels[k]);
		}
		nChannels = 0;
		for (c=0; c<doChannels.length; c++) {
			if (doChannels[c]) nChannels++;
		}
		if (true) print("nChannels = "+nChannels);
		allChannels = toArray(seriesChannelSequences[i], _2DarraysSplitter);
		for (k=0; k<allChannels.length; k++) {
			if (allChannels[k]==0) allChannels[k]="";
			if (true) print("allChannels["+k+"] = "+allChannels[k]);
		}
		print("ProcessFolder2(): series number "+i+":");
		chnColors = toArray(
			channelSequencesColors[channelGroupIndex], _2DarraysSplitter);
		chnSaturations = toArray(
			channelSequencesSaturations[channelGroupIndex], _2DarraysSplitter);
		for (k=0; k<chnSaturations.length; k++)
			print("chnSaturations["+k+"]="+chnSaturations[k]);
		for (k=0; k<chnColors.length; k++)
			print("chnColors["+k+"]="+chnColors[k]);
		//channels, seriesColors, saturations... doivent etre reduits aux 
		//elements pour lesquels doChannels = true
		channels = newArray(nChannels);
		seriesColors = newArray(nChannels);
		saturations = newArray(nChannels);
		q=0;
		for (k=0; k<allChannels.length; k++) {
			if (doChannels[k]) {
				channels[q] = allChannels[k];
				seriesColors[q] = chnColors[k];
				saturations[q] = chnSaturations[k];
				q++;
			}
		}
		print("nChannels="+nChannels);
		for (k=0; k<nChannels; k++) {//ok even if 1st channel(s) ignored
			print("channels["+k+"]="+channels[k]);
			print("seriesColors["+k+"]="+seriesColors[k]);
			print("saturations["+k+"]="+saturations[k]);
		}
		channelColorIndexes = computeColorIndexes(channels, seriesColors);
		compositeStrs = newArray(nChannels);//ancien
		//compositeStrs = newArray(allChannels.length);
		if (dbg)
			print("channelColorIndexes.length = "+channelColorIndexes.length);
		if (dbg) print("Channels to do:");
		if (true) for (k=0; k<channels.length; k++) {
			//print("channels["+k+"] = "+channels[k]);
			print("channelColorIndexes["+k+"]="+channelColorIndexes[k]);
		}
		if (dbg) print("seriesColors.length="+seriesColors.length);
		print("Channel colors:");
		for (k=0; k<channels.length; k++) {
//			print(usedChannels[k] + " : "+
//				compositeChannels[channelColorIndexes[k]]);
			//print(allChannels[k] + " : "+colors[channelColorIndexes[k]]);
			print(channels[k] + " : "+colors[channelColorIndexes[k]]);
			print("saturations["+k+"]="+saturations[k]);
		}
		for (k=0; k<channels.length; k++) {
		//for (k=0; k<allChannels.length; k++) {
			compositeStrs[k]=compositeChannels[channelColorIndexes[k]];
			if (true) print("compositeStrs["+k+"]="+compositeStrs[k]);
		}
		//to be merged, channels must be reordered by increasing c numbers
		reorderedChannels = reorderArray(channels, channels, compositeStrs);
		reorderedCompositeStrs = reorderArray(
									compositeStrs, channels, compositeStrs);
		seriesColors = reorderArray(seriesColors, channels, compositeStrs);
		saturations = reorderArray(saturations, channels, compositeStrs);

		//Debug of wrong projection types
		reorderedChannelIndexes = newArray(channels.length);
		for (k=0; k<channels.length; k++) {
			for (k2=0; k2<channels.length; k2++) {
				if (reorderedChannels[k2]==channels[k]) {
					reorderedChannelIndexes[k] = k2;
					break;
				}
			}
		}

//		print("Process folder(): computeColorIndexes(chns, outputColors):");
//		Contrairement a processFolder() ne permute pas les projection-types
//		entre canaux, mais necessaire pour qu'ils aient la bonne couleur
		channelColorIndexes =
			computeColorIndexes(reorderedChannels, seriesColors);
		channelColorIndexes =
			ensureColorIndexesAreDifferent(channelColorIndexes);
		for (k=0; k<nChannels; k++) {
			print("channels["+k+"] = "+channels[k]);
			print("channelColorIndexes["+k+"] = "+channelColorIndexes[k]);
			print("reorderedChannels["+k+"] = "+reorderedChannels[k]);
			print("reorderedCompositeStrs["+k+"] = "+reorderedCompositeStrs[k]);
			print("seriesColors["+k+"] = "+seriesColors[k]);
			print("saturations["+k+"] = "+saturations[k]);
		}
		extensions = getExtensions(fnames, seriesName);
		if (dbg) print("extensions:");
		if (dbg) for (k=0; k<extensions.length; k++) print(extensions[k]);
		ismultiposition = multipositionSeries[i];
		if (ismultiposition) print("isMultiposition = true");
		nPositions = positionNumbers[i];
		print("nPositions = "+nPositions);
		istimeseries = timeSeries[i];
		if (istimeseries) print("istimeSeries = true");
		else print("istimeSeries = false");
		//if (isTimeFilter(fF)) istimeseries = false;
		//	print("isTimeSeries = false");
		nFrames = getFramesNumber(fnames, seriesName);
		nframesInChannels = getFrameNumbers(fnames, i);
		print("nFrames="+nFrames);
		//seriesName = seriesNames[i];
		wStr = ""; pStr = ""; tStr = "";
		frameInterval = userFrameInterval;
		timeUnit = userTimeUnit;
		if (istimeseries) {
			acquisitionYears = newArray(2); acquisitionMonths = newArray(2);
			acquisitionDays = newArray(2); acquisitionTimes = newArray(2);
		}
		doZprojs = doZprojForChannelSequences[channelGroupIndex];
		projTypes = toArray(projTypesForChannelSequences[channelGroupIndex],
							_2DarraysSplitter);
		for (c=0; c<projTypes.length; c++) {
			print("projTypes["+c+"]="+projTypes[c]);
			print("channelColorIndexes["+c+"]="+channelColorIndexes[c]);
			print("reorderedChannels["+c+"]="+reorderedChannels[c]);
		}
		if (doZprojs)
			to32Bit = needs32Bit(projTypes);
		print("doZprojs="+doZprojs);
		print("to32Bit="+to32Bit);
		startT = firstTimePoint;
		if (lastTimePoint==-1) stopT = nFrames;
		else stopT = lastTimePoint;
		if (doRangeFrom_t1) stopT = round(nFrames*rangeFrom_t1 / 100);
		if (startT<1) startT = 1;
		if (stopT>nFrames) stopT = nFrames;
		if (stopT<startT) stopT = startT;
		if (stopT==-1) stopT = nFrames;
		if (startT>stopT) startT = stopT;
		print("startT="+startT+"  stopT="+stopT);
		timeRange = stopT - startT;
		print("timeRange = "+timeRange);
		frames = timeRange+1;
		print("frames = "+frames);
//DEFINE Z-RANGE
		numberOfPlanes = maxImageDepth;
		print("numberOfPlanes = "+numberOfPlanes);
		if (dbg) print("firstSlice="+firstSlice+
				" lastSlice="+lastSlice);
		if (doRangeAroundMedianSlice) {
			startSlice = numberOfPlanes/2 * 
				(1 - rangeAroundMedianSlice/100);
			stopSlice = numberOfPlanes/2 *
				(1 + rangeAroundMedianSlice/100);
			startSlice = floor(startSlice)-1;
			stopSlice = floor(stopSlice)-1;
		}
		else {
			if (firstSlice<=0)
				startSlice = numberOfPlanes;
			else
				startSlice = firstSlice;
			if (lastSlice<=0)
				stopSlice = numberOfPlanes;
			else
				stopSlice = lastSlice;
		}
		if (dbg) print("startSlice="+startSlice+" stopSlice="+stopSlice);
		if (startSlice<1)
			startSlice = 1;
		if (startSlice>numberOfPlanes)
			startSlice = numberOfPlanes;
		if (stopSlice<1)
			stopSlice = 1;
		if (stopSlice>numberOfPlanes)
			stopSlice = numberOfPlanes;
		slices = abs(stopSlice - startSlice) + 1;
		print("startSlice="+startSlice+" stopSlice="+stopSlice);
		print("slices = "+slices);
//DEFINE Z-RANGE
		if (dbg) {
			for (j=0; j<userPositionsSeriesBySeries.length; j++) {
				print("positionExists["+j+"]="+positionExists[j]);
				print("userPositionsSeriesBySeries["+j+"]="
				+userPositionsSeriesBySeries[j]);
			}
			print("positionNumbers["+i+"]="+positionNumbers[i]);
		}
		getSpatialCalibration(i, allChannels);
		if (numberOfPlanes==0) numberOfPlanes = maxImageDepth;
		if (numberOfPlanes==0) numberOfPlanes = 1;
		print("isSpatiallyCalibrated = "+isSpatiallyCalibrated);
		print("\nComputing output images XYZ calibration:");
		//print("voxelWidth = "+voxelWidth);
		//print("voxelDepth = "+voxelDepth);
		//print("xyUnit = "+xyUnit);			
		if (isSpatiallyCalibrated) {
			voxelW = voxelWidth;
			voxelH = voxelWidth;
			voxelD = voxelDepth;
			if (xyUnit!=userLengthUnit) {
				voxelDepth = recalculateVoxelDepth(voxelDepth,
					userLengthUnit, xyUnit);
			}
			if (resize && resizeFactor!=1) {
				voxelW = voxelWidth / resizeFactor;
				voxelH = voxelHeight / resizeFactor;
			}
			if (doPixelSizeCorrection && pixelSizeCorrection!=1) {
				voxelW = voxelWidth * pixelSizeCorrection;
				voxelH = voxelHeight * pixelSizeCorrection;
			}
		}
		if (!useUserTimeCalibration && istimeseries && nFrames>1) {
			getFrameInterval(fnames, i, extensions);
		}
		positionIndex2 = 0;
		pp = 0;
		if (positionNamesFromND) ndContent = getNDContent(seriesName);
		if (true) print("\npositionIndex3 = "+positionIndex3);
		for (j=positionIndex3; j<positionIndex3+positionNumbers[i]; j++) {
			if (dbg) print("userPositionsSeriesBySeries["+j+"] = "+
					userPositionsSeriesBySeries[j]);
			positionIndex2++;
			if (!positionExists[j] || userPositionsSeriesBySeries[j]==0) {
				continue;
			}
			//if (!isCompletePosition[j]) continue;//problem
			if (positionIndex2==(positionNumbers[i])+1) break;
			pStr2 = "";
			if (ismultiposition) {
				pStr = userPositionsSeriesBySeries[j];
				pStr2 = pStr;
				if (positionNamesFromND)
					pStr2 = getPositionNameFromNDContent(ndContent, pStr);
				//if-block behaviour depends on operands order!
				//if (!isUserPosition || isPositionFilter(fF)
				if (isPositionFilter(fF)
					&& indexOf(pStr+"_", fF)<0
					&& indexOf(pStr+".", fF)<0) {
					print("Position "+userPositionsSeriesBySeries[j]+" skipped");
					continue;
				}
				else
					pp++;
				print("\nProcessing position "+userPositionsSeriesBySeries[j]);
				//print("pp = "+pp);
			}
			outImages = newArray(1);
			//outImages: output-images IDs for series i and position j
			outImageTitles = newArray(1);
			nRois = 1;
			if (doZprojs) slices = 1;
			//rois processing:
			// - create nRois hyperstacks;
			// - paste content of each roi from c,t input-image for
			//   selected z-positions
			if (crop) {
				//populate RoiManager with regions to extracte from input images
				getRoisFromImage(prefixLessRoiImages, seriesName, channels,
					userPositionsSeriesBySeries[j]);
				nRois = roiManager("count");
				if (nRois==0) {
					print("Found no rois for extraction: position skipped");
					continue;
				}
				newImage("Temp", "8-bit black", 1, 1, 1);
				tmpID = getImageID();
				print("nRois = "+nRois);
				outImages = newArray(nRois);
				outImageTitles = newArray(nRois);
				suffix = "";
				if (resize && resizeFactor!=1)
					suffix += "_resize"+resizeFactor;
				if (startSlice!=1 || stopSlice!=numberOfPlanes)
					suffix += "_z"+startSlice+"-"+stopSlice;
				if (istimeseries && startT!=1 && stopT!=nFrames)
					if (startT!=1 || stopT!=lastTimePoint)
						suffix += "_t"+startT+"-"+stopT;
				for (r=0; r<nRois; r++) {
					//prepare extracted output images for position j
					roiManager("select", r);
					getSelectionBounds(x, y, w1, h1);
					outputName = seriesName+pStr2+"_x"+x+"y"+y+suffix;
//if input image scaled at import, scale roi but name with original coordinates
					if (resize && resizeFactor!=1)
						run("Scale... ", "x="+resizeFactor+" y="+resizeFactor);
					getSelectionBounds(x, y, w1, h1);
					//may fail if type=="RGB":
					newImage(outputName,
						type+" color-mode", w1, h1, nChannels, slices, frames);
					//color-mode because Copy-Paste disabled in composite-mode
					if (dbg) print("roiw="+w1+"  roih="+h1);
					outImageTitles[r] = getTitle();//= outputName
					outImages[r] = getImageID();
				}
				print("Currently open images: "+nImages);
				selectImage(tmpID);
				close();
			}
			else {
				nRois = 1;
				w = maxImageWidth;
				h = maxImageHeight;
				//may fail if type=="RGB":
				newImage(seriesName+pStr2,
						type+" color-mode", w, h, nChannels, slices, frames);
				outImages[0] = getImageID();
				if (dbg) print("outImages[0] = "+outImages[0]);
			}
			tpoints = stopT-startT+1;
			expectedNFiles = nChannels*tpoints;
			missingFilenames = newArray(expectedNFiles);
			missingChannels = newArray(expectedNFiles);
			missingTimepoints = newArray(expectedNFiles);
			missingFileIndex = 0;
			if (istimeseries) {
				print("startT="+startT+"  stopT="+stopT);
				print("Processing "+tpoints+" timepoints:");
			}
			tt = 0;
			for (t=startT; t<=stopT; t++) {
				if (istimeseries) {
					print("t"+t);
					tStr = "_t" + t;
					if (isTimeFilter(fF) && indexOf(tStr+"_", fF)<0
							&& indexOf(tStr+".", fF)<0) {
						print("skip timepoint t = "+t);
						continue;
					}
					else
						tt++;
				}
				channelsStr = "";
				for (c=0; c<nChannels; c++) {
					//Open input file for series i, channel c,
					//position j, timepoint t
					//if (nChannels>1) {
						wStr = reorderedChannels[c];//permute canaux
						//wStr = channels[c];//decale w2 en w1 si w1 decoche
						//print("reorderedChannels["+c+"] = "+
						//		reorderedChannels[c]);
						if (isWaveFilter(fF) && indexOf(wStr, fF)<0) {
							continue;
						}
						if (timeRange>0 && nframesInChannels[c]==1 &&
								ignoreSingleTimepointChannels) {
							nChannels--;
							continue;
						}
					//}
					if (extensions[c]==0) extensions[c]="";
					fn = seriesName+wStr+pStr+tStr+extensions[c];
					if (dbg) {
						print("seriesName = "+seriesName); print("wStr = "+wStr);
						print("pStr = "+pStr); print("pStr2 = "+pStr2);
						print("tStr = "+tStr);
						print("extensions[c] = "+extensions[c]);
						print("fn = "+fn);
					}
					path = dir1+fn;
					projID = 0;
					if (!File.exists(path)) {
						print("missingFileIndex = "+missingFileIndex);
						missingFilenames[missingFileIndex] = fn;
						missingChannels[missingFileIndex] = c;
						missingTimepoints[missingFileIndex] = tt;//t ?
						missingFileIndex++;
						print("Cannot find file\n"+dir1+"\n"+fn);
						print("for channel "+c+", timepoint "+t);
						continue;
					}
					else {
//Rather than delete unwanted slices, copy from startSlice to stopSlice to avoid
//distinguish loops for (stopSlice < startSlice) and (stopSlice > startSlice)
						//DESACTIVER POUR ESSAI IMPORT
						if (abs(stopSlice-startSlice)+1==numberOfPlanes) {
							open(path);
							if (startSlice==numberOfPlanes &&
									numberOfPlanes>1 && !doZprojs)
								run("Reverse");
						}
						else {
							openZRange(path, rangeAroundMedianSlice/100,
									startSlice, stopSlice);
						}
/*
						if (resize && resizeFactor!=1) {
							print("resizeFactor = "+resizeFactor);
							//may be faster or slower than open and resize
							importAndScale(dir1, fn, resizeFactor,
									startSlice, stopSlice);
							w0r = getWidth; h0r = getHeight;
							print("After Resizing image");
							print("width = "+w0r+"  height = "+h0r);
						}
*/
						if (resize && resizeFactor!=1) resizeImage(resizeFactor);
						inputImageID = getImageID();
						if (doZprojs && nSlices>1) {
/*
							run("Z Project...", "projection=["+projTypes[c]+"]");
*/
					//		print("Image: "+getTitle());
							print ("c="+c+": projection=["+
									projTypes[reorderedChannelIndexes[c]]+"]");
							run("Z Project...", "projection=["+
									projTypes[reorderedChannelIndexes[c]]+"]");

							projID = getImageID();
							if (to32Bit) run("32-bit");
							projID = getImageID();
							slices = 1;
						}
					}//File.exists(path)
//					print("slices = "+slices);
					if (!doZprojs) inputImageID = getImageID();
					inputStackSize = nSlices;
					if (crop) {//then nRois>0
						Stack.getDimensions(width, height,
								nchannels, depth, nframes);
						for (r=0; r<nRois; r++) {
							selectImage(inputImageID);
							if (doZprojs && nSlices>1) selectImage(projID);
							roiManager("select", r);
							//if scaled input image, scale roi:
							if (resize && resizeFactor!=1)
								run("Scale... ",
									"x="+resizeFactor+" y="+resizeFactor);
							Roi.getBounds(roiX, roiY, roiW, roiH);
							if (roiW*roiH>0 && (roiW<width || roiH<height)) {
								makeRectangle(roiX, roiY, roiW, roiH);
							}
							if (dbg) print("Roi "+r+"  c+1 = "+(c+1));
							for (z=1; z<=slices; z++) {
								selectImage(inputImageID);
								if (doZprojs && nSlices>1) selectImage(projID);
								if (dbg) {
									tit = getTitle();
									print("Selecting "+tit);
									if (c==0 && t==1)//adds '.tif' for each r
										saveAs("tiff", dir2+tit+".tif");
								}
								if (inputStackSize>1) setSlice(z);
								//if (inputStackSize==slices) setSlice(z);
								//if not, inputStackSize=1,
								//copy single input slice to all output slices
								run("Copy");
								selectImage(outImages[r]);
								run("Select All");//if not may fill with black!
								Stack.setPosition(c+1, z, tt);
								run("Paste");
							}
							if (dbg)
								print("Copy from  z = "+1+"  to  z = "+slices);
							run("Select None");
						}
					}
					else {
						//print("Copy input image slices to output image");
						for (z=1; z<=slices; z++) {
							selectImage(inputImageID);
							if (doZprojs && nSlices>1) selectImage(projID);
							run("Select All");
							if (inputStackSize>1) setSlice(z);
							//if (inputStackSize==slices) setSlice(z);
							//if not, inputStackSize=1,
							//copy single slice to all output slices
							run("Copy");
							selectImage(outImages[0]);
							Stack.setPosition(c+1, z, tt);
							//Stack.setPosition(c+1, z, t-startT+1);
							run("Select All");//if not may fill with black!
							run("Paste");
						}
						run("Select None");
					}
					selectImage(inputImageID);
					if (doZprojs && nSlices>1) selectImage(projID);
					bitdepth = bitDepth();
					type = getImageType(bitdepth);
					Stack.getDimensions(w, h, nchn, nslices, frames);
					//print("i="+i+" j="+j+" t="+t+" c="+c);
					if (inputImageID<0 && isOpen(inputImageID)) {
						selectImage(inputImageID);
						close();
					}
					if (projID<0 && doZprojs && isOpen(projID)) {
						selectImage(projID);
						close();
					}
				}//channel c
			}//time t
			if (dbg) {
				print("lastTimePoint="+lastTimePoint+
					"  firstTimePoint="+firstTimePoint);
				print("\nstopT-startT = "+(stopT-startT));
			}
			if (istimeseries)
				print("frameInterval = "+frameInterval+" "+timeUnit);
			print("\nCalibrating & Saving:");
			if (dbg) print("nRois = "+nRois);
			for (r=0; r<nRois; r++) {//Calibrate & save
				selectImage(outImages[r]);
				if (r==0) {
					getDimensions(ww, hh, nch, ns, nf);
					if (ns<2) voxelDepth = 0;
				}

				if (isSpatiallyCalibrated && !useUserXYZCalibrations)
					setVoxelSize(voxelW, voxelH, voxelDepth, xyUnit);
				else
					setVoxelSize(userPixelSize, userPixelSize,
						voxelDepth, userLengthUnit);
/*
				if (useUserXYZCalibrations) setVoxelSize(userPixelSize,
						userPixelSize, voxelDepth, userLengthUnit);
*/
				if (istimeseries) {
					if (dbg) print("nChannels = "+nChannels);
					if (nChannels*slices*timeRange>1) {
						selectImage(outImages[r]);
						Stack.setDimensions(nChannels, nslices, timeRange+1);
					}
					Stack.setTUnit(timeUnit);
					Stack.setFrameInterval(frameInterval);
				}
				if (isTimeFilter(fF)) {
					selectImage(outImages[r]);
					Stack.setDimensions(nChannels, slices, 1);
				}
				missingFilenames = Array.trim(missingFilenames,
						missingFileIndex);
				missingChannels = Array.trim(missingChannels,
							missingFileIndex);
				missingTimepoints = Array.trim(missingTimepoints,
						missingFileIndex);
				id = outImages[r];
				if (missingFilenames.length>0)
					addMissingFilesInfos(id, dir1, missingFilenames,
							missingChannels, missingTimepoints, 
							seriesColors);
//Marche avec ou sans infra peut-etre parce que qd on cree un hyperstack,
//les luts sont r, g, b, gray, cyan, magenta, yellow
				if (type!="RGB")
					setLuts(id, channelColorIndexes);
				enhanceContrast(id, saturations);
				labelChannels(id, reorderedChannels);
				//labelChannels(id, channels);
				Stack.getDimensions(w,h,nch,slices,frames);
				if (type!="RGB"&& nch==1 && channels[0]=="") {//possible problem
					//print("run("+colors[channelColorIndexes[0]]+")");
					//getLUT() finds LUT if wavelength not in filename
					lutName = getLUT(illumSetting);
					print("lutName = "+lutName);
					run(lutName);
				}
				setMetadata("Info", info);
				selectImage(outImages[r]);
				title = getTitle();
				Stack.setDisplayMode("composite");
				print(title+".tif");
				saveAs("tiff", dir2+title+".tif");
				close();
			}//roi r
			saveLog(logCount++);
		}//position j
		positionIndex3 += positionNumbers[i];
		print("");
	}//series i
	print("\nEnd processFolder2(): nImages = "+nImages());
}//processFolder2()

//80 chars:
//23456789 123456789 123456789 123456789 123456789 123456789 123456789 1234567890
