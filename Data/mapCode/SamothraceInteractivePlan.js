//generating text description from input URL and loading to sidebar
function readTxt(desc, url, var) {
    var splitText;
    var outText = "Start Text";
    var readText = $.ajax({
        url: url + desc + "/SamoWebsite_" + desc + ".txt",
        dataType: "text"
    })
    $.when(readText).done(function () {
        var text = readText.responseText;
        splitText = text.match(/[^\r\n]+/g);
        var capcount = 0;
        var bibState = 0;
        outText = "";
        for (var n = 0; n < splitText.length; n++) {
            var newText = splitText[n];
            if (newText.match("JAG_UNEDITED|Glennon") != null) {
                newText = "";
            } else if (newText.match("Title: |Monument: ") != null) {
                newText = newText.replace('Title: ', '');
                newText = newText.replace('Monument: ', '');
                newText = '<text style="font-size:30px;"><b>' + newText + '</b></text><br><br>';
            } else if (newText.match("Subheader: |Part: ") != null) {
                newText = newText.replace('Subheader: ', '');
                newText = newText.replace('Part: ', '');
                newText = '<text style="font-size:16px;"><b>' + newText + '</b></text><br>';
            } else if (newText.match("Header: ") != null) {
                newText = newText.replace('Header: ', '');
                newText = '<text style="font-size:24px;"><b>' + newText + '</b></text><br>';
            } else if (newText.match("Bibliography:") != null) {
                newText = '<text style="font-size:20px;"><b>' + newText + '</text></b><br>';
                bibState = 1;
            } else if (newText.match("Caption:") != null) {
                capcount += 1;
                const capUrl = url + desc + "/SamoWebsite_" + desc + "_Image" + capcount + ".jpg";
                newText = newText.replace('Caption:', '<img src="' + capUrl + '" ' + width + ' /><br>');
                newText = '<text style="font-size:11px;">' + newText + '</text><br><br>';
            } else if (newText.match("Date:|Material|Location:") != null) {
                newText = newText.replace('Date: ', '');
                newText = newText.replace('Material: ', '');
                newText = newText.replace('Location: ', '');
                var nextText = splitText[n + 1];
                if (nextText.match("Date:|Material|Location:") != null) {
                    newText = '<text style="font-size:11px;">' + newText + '</text><br>';
                } else {
                    newText = '<text style="font-size:11px;">' + newText + '</text><br><br>';
                }
            } else if (newText.trim().length === 0) {
                newText += '<br>';
            } else {
                if (bibState == 0) {
                    newText = '<text style="font-size:14px;">' + newText + '</text><br><br>';
                } else {
                    newText = '<text style="font-size:11px;">' + newText + '</text><br><br>';
                }
            }
            outText += newText.trim();
        }
        outText += '<text style="font-size:10px;"><br>---<br> Plan date: 2021 - 2022. Dates provided in the legend based on interpretations by Karl Lehmann and Phyllis Williams Lehmann.</text>'
        for (var i = 0; i < 3; i++) {
            outText = outText.replace('<br><br><br>', '<br><br>');
        }

        //sidebar.setContent(outText);
        window[var] = outText;
    });
}

//reseting scroll position on layer click
function resetScroll() {
    window.setTimeout(() => {
        document.getElementById("sidebar").scrollTop = 0;
    }, 1);
}

//package for updating sidebar output
function updateOutput(desc, url, var) {
    readTxt(desc, url, var);
    setTimeout(function () {
        sidebar.setContent(var)
        resetScroll()
    }, 100);
}