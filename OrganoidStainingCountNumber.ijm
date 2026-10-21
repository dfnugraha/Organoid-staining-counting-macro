// Fiji macro: strict overlap counting, corrected stricter version
// Channel 1 = DAPI
// Channel 2 = SPC
// Channel 3 = AcTub

orig = getTitle();

// ---------- SETTINGS ----------

// DAPI nucleus detection
dapiThresholdMethod = "Otsu dark";
minNucleusSize = 150;
maxNucleusSize = 1.0E12;
minCircularity = 0.30;
maxCircularity = 1.00;
doWatershed = false;

// SPC / AcTub mask threshold
spcThresholdMethod   = "Triangle dark";
actubThresholdMethod = "Triangle dark";

// cleanup
spcOpenTimes   = 3;
actubOpenTimes = 3;

// shrink masks
spcErodeTimes   = 3;
actubErodeTimes = 3;

// stronger overlap requirement
minOverlapPixels = 80;

// optional smoothing
useMedianFilter = true;
medianRadius = 1;

// -----------------------------

run("Clear Results");
roiManager("Reset");
run("Set Measurements...", "area mean integrated redirect=None decimal=3");

getDimensions(w, h, c, z, t);
if (c != 3) exit("Expected 3 channels, found " + c);

// Duplicate raw channels
selectWindow(orig);
Stack.setChannel(1);
run("Duplicate...", "title=DAPI_raw");
selectWindow("DAPI_raw");
run("Set Scale...", "distance=0");

selectWindow(orig);
Stack.setChannel(2);
run("Duplicate...", "title=SPC_raw");
selectWindow("SPC_raw");
run("Set Scale...", "distance=0");

selectWindow(orig);
Stack.setChannel(3);
run("Duplicate...", "title=ACTUB_raw");
selectWindow("ACTUB_raw");
run("Set Scale...", "distance=0");

// ---------- SPC mask ----------
selectWindow("SPC_raw");
run("Duplicate...", "title=SPC_mask");
selectWindow("SPC_mask");
run("8-bit");
if (useMedianFilter) run("Median...", "radius="+medianRadius);
setAutoThreshold(spcThresholdMethod);
setOption("BlackBackground", false);
run("Convert to Mask");
for (k = 0; k < spcOpenTimes; k++) run("Open");
for (k = 0; k < spcErodeTimes; k++) run("Erode");

// ---------- AcTub mask ----------
selectWindow("ACTUB_raw");
run("Duplicate...", "title=ACTUB_mask");
selectWindow("ACTUB_mask");
run("8-bit");
if (useMedianFilter) run("Median...", "radius="+medianRadius);
setAutoThreshold(actubThresholdMethod);
setOption("BlackBackground", false);
run("Convert to Mask");
for (k = 0; k < actubOpenTimes; k++) run("Open");
for (k = 0; k < actubErodeTimes; k++) run("Erode");

// ---------- DAPI nuclei ----------
selectWindow("DAPI_raw");
run("Duplicate...", "title=DAPI_mask");
selectWindow("DAPI_mask");
run("8-bit");
if (useMedianFilter) run("Median...", "radius="+medianRadius);
setAutoThreshold(dapiThresholdMethod);
setOption("BlackBackground", false);
run("Convert to Mask");
run("Fill Holes");
if (doWatershed) run("Watershed");

run("Analyze Particles...", 
    "size="+minNucleusSize+"-"+maxNucleusSize+
    " circularity="+minCircularity+"-"+maxCircularity+
    " exclude add");

n = roiManager("count");
if (n == 0) exit("No nuclei detected.");

roiManager("Show All");

// ---------- Count overlap ----------
dapiOnly = 0;
dapiSpcOnly = 0;
dapiActubOnly = 0;
triplePos = 0;

for (i = 0; i < n; i++) {

    // SPC overlap
    selectWindow("SPC_mask");
    roiManager("Select", i);
    row1 = nResults;
    run("Measure");
    area1 = getResult("Area", row1);
    mean1 = getResult("Mean", row1);
    spcOverlapPixels = (area1 * mean1) / 255.0;
    spcPos = spcOverlapPixels >= minOverlapPixels;

    // AcTub overlap
    selectWindow("ACTUB_mask");
    roiManager("Select", i);
    row2 = nResults;
    run("Measure");
    area2 = getResult("Area", row2);
    mean2 = getResult("Mean", row2);
    actubOverlapPixels = (area2 * mean2) / 255.0;
    actubPos = actubOverlapPixels >= minOverlapPixels;

    if (!spcPos && !actubPos) dapiOnly++;
    else if (spcPos && !actubPos) dapiSpcOnly++;
    else if (!spcPos && actubPos) dapiActubOnly++;
    else triplePos++;
}

totalSpcPos = dapiSpcOnly + triplePos;

run("Clear Results");
setResult("Metric", 0, "Total DAPI nuclei");
setResult("Value", 0, n);
setResult("Metric", 1, "DAPI only");
setResult("Value", 1, dapiOnly);
setResult("Metric", 2, "DAPI+SPC only");
setResult("Value", 2, dapiSpcOnly);
setResult("Metric", 3, "DAPI+AcTub only");
setResult("Value", 3, dapiActubOnly);
setResult("Metric", 4, "DAPI+SPC+AcTub");
setResult("Value", 4, triplePos);
setResult("Metric", 5, "Total SPC+ nuclei");
setResult("Value", 5, totalSpcPos);
updateResults();

print("\\Clear");
print("Image: " + orig);
print("Total DAPI nuclei: " + n);
print("DAPI only: " + dapiOnly);
print("DAPI+SPC only: " + dapiSpcOnly);
print("DAPI+AcTub only: " + dapiActubOnly);
print("DAPI+SPC+AcTub: " + triplePos);
print("Total SPC+ nuclei: " + totalSpcPos);