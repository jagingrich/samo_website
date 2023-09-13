//pulling text description from url
function readTxt(desc, url) {
    return $.ajax({
        url: url + desc + "/SamoWebsite_" + desc + ".txt",
        dataType: "text",
        success: function (response) {}
    });
}

//html formating for text strings
function textHTMLOutput(text, { size = 16, bold = false, italics = false, paragraph = 'paragraph', linebreak = true } = {}) {
    var input = text;
    var head = '<text style="font-size:' + size + 'px;">';
    var foot = '</text><br>';
    if (bold == true) {//html for bold
        head += '<b>';
        foot = '</b>' + foot;
    }
    if (italics == true) {//html for italics
        head += '<i>';
        foot = '</i>' + foot;
    }
    if (linebreak == true) {//adding an additional linebreak
        foot += '<br>';
    }
    switch (paragraph) {//paragraph styling
        case 'indent':
            head = '<div style="text-indent: 36px;">' + head;
            foot += '</div>'
            break;
        case 'hanging':
            head = '<div style="text-indent: -36px; padding-left: 36px;">' + head;
            foot += '</div>'
            break;
        default:
    }
    return head + input + foot;//output
}

//formatting text output for sidebar
function splitTxt(text, { remove = [null], replace = [[keyword = null, replacement = null]]}) {
    //split input text to individual lines
    var startText = text.match(/[^\r\n]+/g);
    var splitText = [];

    //string of keywords to remove
    var remCat = remove[0];
    if (remove.length > 1) {
        for (var c = 1; c < remove.length; c++) {
            remCat += '|' + remove[c];
        }
    }

    //searching each line for replacement keywords, text codes
    for (var n = 0; n < startText.length; n++) {
        var newText = startText[n].trim();

        //replacing lines based on replacement keywords
        for (var r = 0; r < replace.length; r++) {
            var repSub = replace[r];
            if (newText.match(repSub[0]) != null) {
                newText = repSub[1];
            }
        }

        //generating line/paragraph codes
        if (newText.match(remCat) == null) { //removing lines based on removal keywords
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
    return splitText;//output
}

function outText(desc, url, text, { remove = [null], replace = [[keyword = null, replacement = null]] }) {
    var splitText = splitTxt(text, { remove: remove, replace: replace });
    var outText = "";
    var capcount = 0;
    var defaultSize = 14;
    var defaultPara = 'paragraph';
    //formatting each text output based on text code
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
                newText = textHTMLOutput(newText, {size: 16, bold: true, linebreak: false});
                break;
            case 'Header':
                newText = textHTMLOutput(newText, {size: 24, bold: true, linebreak: false});
                break;
            case 'Bibliography':
                defaultSize = 11;
                defaultPara = 'hanging';
                newText = textHTMLOutput(newText, {size: 18, bold: true, linebreak: false});
                break;
            case 'Caption':
                capcount += 1;
                const capUrl = '<img src="' + url + desc + "/SamoWebsite_" + desc + "_Image" + capcount + ".jpg" + '" ' + width + ' /><br>';
                if (newText.length === 0) {
                    newText = '<br>';
                } else {
                    newText = textHTMLOutput(newText, {size: 11});
                }
                newText = capUrl + newText;
                break;
            case 'Date':
            case 'Material':
            case 'Location':
                var nextText = splitText[n + 1];
                switch (nextText[0]) {
                    case 'Date':
                    case 'Material':
                    case 'Location':
                        newText = textHTMLOutput(newText, {size: 11, linebreak: false});
                        break;
                    default:
                        newText = textHTMLOutput(newText, {size: 11});
                        break;
                }
                break;
            case 'Body':
                newText = textHTMLOutput(newText, {size: defaultSize, paragraph: defaultPara});
                break;
            default:
                newText = '<br>';
        }
        outText += newText;
    }
    //appending plan date and date attribution
    outText += textHTMLOutput('---', { size: 10, linebreak: false });
    outText += textHTMLOutput('Dates provided in the legend based on interpretations by Karl Lehmann and Phyllis Williams Lehmann', { size: 10, linebreak: false });
    outText += textHTMLOutput('Plan date: 2021 - 2022', { size: 10, linebreak: false });
    //remove extra line breaks
    while (outText.match('<br><br><br>') != null) {
        outText = outText.replaceAll('<br><br><br>', '<br><br>');
    }
    return outText;//output
}

//reseting scroll position on layer click
function resetScroll() {
    window.setTimeout(() => {
        document.getElementById("sidebar").scrollTop = 0;
    }, 1);
}

//packaged function for updating sidebar output
function updateOutput(desc, url, { remove = [null], replace = [[keyword = null, replacement = null]] }) {
    //pulling text from url, formatting when done, loading to sidebar
    readTxt(desc, url).done(function (response) {
        description = outText(desc, url, response, { remove: remove, replace: replace });
        sidebar.setContent(description);
    });
    //reset scroll position
    setTimeout(function () {
        resetScroll();
    }, 10);
}