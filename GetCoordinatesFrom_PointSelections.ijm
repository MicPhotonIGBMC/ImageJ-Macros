/** GetCoordinatesFrom_PointSelections.ijm
 * This macro demonstrates how to get coordinates from a Multi-point selection
 * Author Marcel Boeglin 20200913-14
 */


print("\\Clear");
var pointsX=newArray(1), pointsY=newArray(1);
var xpoints, ypoints;
if (isOpen("PointRoisImage")) {
	selectWindow("PointRoisImage");
	run("Select None");
}
else newImage("PointRoisImage", "8-bit black", 512, 512, 1);
image = getImageID();
setTool("multipoint");
setTool("multipoint");
waitForUser("Please draw point rois using Multi-point Tool.");
if (selectionType() == 10) {
	Overlay.addSelection;
	print("Roi.getType = "+Roi.getType);
}
run("Select None");
setTool("point");
waitForUser("Please draw point rois using Point Tool."+
		"\nTo add more than one point, add to overlay by ctrl-B");
if (selectionType() == 10) {
	Overlay.addSelection;
	print("Roi.getType = "+Roi.getType);
}
print("Overlay.size = "+ Overlay.size);
getAndHighlightPointRois(image);
run("Select None");


function highlightPointRois(img, xs, ys) {
	if (!isOpen(img)) return;
	selectImage(img);
	multi = xs.length>1;
	str = "\nCoordinates from ";
	if (multi) str += "Multi-point:";
	else str += "Single point:";
	print(str);
	for (r=0; r<xs.length; r++) {
		str = "";
		if (multi) str = ""+(r+1)+" : ";
		print(str+"x = "+xs[r]+"    "+"y = "+ys[r]);
		x = xs[r] - 25;
		y = ys[r] - 25;
		makeOval(x, y, 50, 50);
		wait(500);
	}
}

function getAndHighlightPointRois(img) {
	if (!isOpen(img)) return false;
	selectImage(img);
	nRois = Overlay.size;
	pointsX = newArray(nRois);
	pointsY = newArray(nRois);
	for (i=0; i<nRois; i++) {
		setSlice(1);
		Overlay.activateSelection(i);
		if (getSliceNumber()>1) continue;
		if (selectionType()!= 10) continue;//10=point
		getSelectionCoordinates(xpoints, ypoints);
		highlightPointRois(img, xpoints, ypoints);
	}
}
