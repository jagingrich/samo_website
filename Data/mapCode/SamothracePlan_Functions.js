//pulling text description from url
function readTxt(desc, url) {
    return $.ajax({
        url: url + desc + "/SamoWebsite_" + desc + ".txt",
        dataType: "text",
        success: function (response) {}
    });
}

function textHTMLOutput(text, { size = 16, bold = false, italics = false, hanging = false, space = true } = {}) {
    var input = text;
    var head = '<text style="font-size:' + size + 'px;">';
    var foot = '</text><br>';
    if (bold == true) {
        head += '<b>';
        foot = '</b>' + foot;
    }
    if (italics == true) {
        head += '<i>';
        foot = '</i>' + foot;
    }
    if (space == true) {
        foot += '<br>';
    }
    if (hanging == true) {
        head = '<div style="text-indent: -36px; padding-left: 36px;">' + head;
        foot += '</div>'
    }
    return head + input + foot;
}

//formatting text output for sidebar
function splitText(desc, url, text, remove = [], replace = [null,null]) {
    
    var startText = text.match(/[^\r\n]+/g);
    var splitText = [];

    for (var n = 0; n < startText.length; n++) {
        var newText = startText[n].trim();
        if (newText.match("Bibliography:") != null) {
            newText = 'Bibliography: Selected Bibliography';
        }
        if (newText.match("JAG_UNEDITED|Glennon") == null) {
            var txtCode = newText.split(' ')[0];
            if (txtCode.match(":") != null) {
                splitText.push([txtCode.replace(':', ''), newText.replace(txtCode, '').trim()]);
            } else {
                if (newText.trim().length === 0) {
                    splitText.push(["Space", newText.trim()]);
                } else {
                    splitText.push(["Body", newText.trim()]);
                }
            }
        }
    }
    console.log(splitText);
    return splitText;
}

function outText(desc, url, text, remove = [], replace = [null, null]) {
    var splitText = splitText();
    var outText;
    var capcount = 0;
    var defaultSize = 14;
    var defaultPara = false;
    outText = "";
    for (var n = 0; n < splitText.length; n++) {
        var input = splitText[n];
        var newText = input[1];
        switch (input[0]) {
            case 'Title':
            case 'Monument':
                newText = textHTMLOutput(newText, {size: 30, bold: true});
                break;
            case 'Subheader':
            case 'Part':
                newText = textHTMLOutput(newText, {size: 16, bold: true, space: false});
                break;
            case 'Header':
                newText = textHTMLOutput(newText, {size: 24, bold: true, space: false});
                break;
            case 'Bibliography':
                defaultSize = 11;
                defaultPara = true;
                newText = textHTMLOutput(newText, {size: 18, bold: true, space: false});
                break;
            case 'Caption':
                capcount += 1;
                const capUrl = url + desc + "/SamoWebsite_" + desc + "_Image" + capcount + ".jpg";
                if (newText.length === 0) {
                    newText = '<br>';
                } else {
                    newText = textHTMLOutput(newText, {size: 11});
                }
                newText = '<img src="' + capUrl + '" ' + width + ' /><br>' + newText;
                break;
            case 'Date':
            case 'Material':
            case 'Location':
                var nextText = splitText[n + 1];
                switch (nextText[0]) {
                    case 'Date':
                    case 'Material':
                    case 'Location':
                        newText = textHTMLOutput(newText, {size: 11, space: false});
                        break;
                    default:
                        newText = textHTMLOutput(newText, {size: 11});
                        break;
                }
                break;
            case 'Body':
                newText = textHTMLOutput(newText, {size: defaultSize, hanging: defaultPara});
                break;
            default:
                newText = '<br>';
        }
        outText += newText;
    }

    outText += textHTMLOutput('---', { size: 10, space: false });
    outText += textHTMLOutput('Dates provided in the legend based on interpretations by Karl Lehmann and Phyllis Williams Lehmann', { size: 10, space: false });
    outText += textHTMLOutput('Plan date: 2021 - 2022', { size: 10, space: false });
    for (var i = 0; i < 3; i++) {
        outText = outText.replaceAll('<br><br><br>', '<br><br>');
    }
    return outText;
}

//reseting scroll position on layer click
function resetScroll() {
    window.setTimeout(() => {
        document.getElementById("sidebar").scrollTop = 0;
    }, 1);
}

//packaged function for updating sidebar output
function updateOutput(desc, url) {
    //pulling text from url, formatting when done, loading to sidebar
    readTxt(desc, url).done(function (response) {
        description = outText(desc, url, response);
        sidebar.setContent(description);
    });
    //reset scroll position
    setTimeout(function () {
        resetScroll();
    }, 10);
}