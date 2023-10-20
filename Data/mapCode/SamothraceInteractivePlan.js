//FUNCTIONS THAT CREATE AND RUN THE SANCTUARY OF THE GREAT GODS SAMOTHRACE INTERACTIVE MAP PLAN
//Jared Gingrich 2023

//update initial inputs for layers, groupings, urls, etc.
function updateInputs() {
    groups = [["Actual State Plan", "ActualState"], ["Restored State Plan", "RestoredState"]];
    tileLayers = ['https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_ActualStatePlan_3857/{z}/{x}/{y}.png',
        'https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_ActualStateMonuments_3857/{z}/{x}/{y}.png',
        'https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_RestoredStatePlan_3857/{z}/{x}/{y}.png',
        'https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_RestoredStateMonuments_3857/{z}/{x}/{y}.png'];
    attribution = 'JAG2023 | <a href="https://www.samothrace.emory.edu/">American Excavations Samothrace';
    jsonLayers = ['https://cdn.rawgit.com/jagingrich/samo_website/main/Data/mapFeatures/SamoWeb_ActualStatePlan_Overlay.geojson',
        'https://cdn.rawgit.com/jagingrich/samo_website/main/Data/mapFeatures/SamoWeb_RestoredStatePlan_Overlay.geojson'];

    dropdownName = 'dropdown-contents';
    //setting description creation vars
    url = 'https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapDescriptions/';
    defaultWebID = '(0)Introduction';
    dropdownDefault = ['<option value="' + defaultWebID + '" disabled selected hidden>Select Monument</option>',
    '<option value="' + defaultWebID + '">About: Interactive Plan</option>'];
    remove = ['JAG_UNEDITED', 'Glennon'];
    replace = [['Bibliography:', 'Bibliography: Selected Bibliography']];
}

//creating divs for parts of interactive plan in map, overlay divs
function divCreate(divName, divContainer, type = 'div', functionOnCreate = null) {
    L.Control.newDiv = L.Control.extend({
        addTo: function (placeholder) {
            // Attach new div to input container
            var container = L.DomUtil.get(placeholder);
            var newDiv = L.DomUtil.create(type, divName, container);
            L.DomEvent.disableClickPropagation(newDiv);
            newDiv.id = divName;

            if (functionOnCreate != null && typeof (functionOnCreate) == 'function') {
                functionOnCreate(newDiv);
            }           

            return this;
        },
        onRemove: function (placeholder) { }
    });
    var outDiv = new L.Control.newDiv();
    outDiv.addTo(divContainer);
}

//formatting for tile layers
function tileLayer(url, setAttribution = false) {
    if (setAttribution) {
        return L.tileLayer(url, {
            maxZoom: 22,
            minZoom: 17,
            tms: true,
            attribution: attribution
        });
    } else {
        return L.tileLayer(url, {
            maxZoom: 22,
            minZoom: 17,
            tms: true
        });
    }
}

//formatting for json overlay layers
function jsonLayer(json) {
    return L.geoJSON(json, {
        style: styleTransparent,
        onEachFeature: onEachFeature
    });
}

//transparent overlay layer style
function styleTransparent() {
    return {
        fillColor: '#00000000',
        weight: 0,
        opacity: 0,
        color: '#00000000',
        fillOpacity: 0
    }
}

//mouseover highlight behavior and highlight reset
function highlightFeature(e) {
    e.target.setStyle({
        fillColor: '#FFF',
        weight: 2.5,
        opacity: 1,
        color: '#FFF',
        dashArray: '',
        fillOpacity: 0.25
    });

    if (!L.Browser.ie && !L.Browser.opera && !L.Browser.edge) {
        e.target.bringToFront();
    }
}

//this is the reset
function resetHighlight(e) {
    e.target.setStyle(styleTransparent());
}

//zoom to feature from given code
function zoomToFeature(features, webCode) {
    if (webCode != defaultWebID) {
        //select objects
        var selected = [];
        features.forEach(function (f) {
            if (f.properties.WebCode == webCode) {
                selected.push(L.geoJSON(f));
            }
        });

        //zoom to bounds
        map.flyToBounds(L.featureGroup(selected).getBounds());
    }
    else {
        //zoom to all map bounds
        map.flyToBounds(mapbounds);
    }
}

//selecting feature: click or dropdown
function selectFeature(webCode) {
    //update text and dropdown
    updateText(webCode);

    //zoom to selection
    zoomToFeature(getAllFeatures(null, control), webCode);
}

//layer responsiveness
function onEachFeature(feature, layer) {
    layer.on({
        mouseover: highlightFeature,
        mouseout: resetHighlight,
        click: (e, event) => selectFeature(e.target.feature.properties.WebCode)
    });
}

//on changing dropdown selection
function onSelect() {
    var dropdown = document.getElementById(dropdownName);
    var index = dropdown.options.selectedIndex;
    if (dropdown[index].value == defaultWebID) {
        selectFeature(defaultWebID)
    } else {
        selectFeature(dropdown[index].value);
    }
}

//updating text and dropdown selection
function updateText(webCode) {
    //update text output code
    webID = webCode;
    updateOutput(sidebarText, webID);

    //update dropdown
    if (document.getElementById(dropdownName)) {
        var dropdown = document.getElementById(dropdownName);
        dropdown.value = webID;
    }
}

//finding all features in map
function getAllFeatures(inputMap = null, layerControl = null) {
    var feats = [];
    if (inputMap != null && typeof (inputMap) == 'object') {
        Object.values(inputMap._layers).forEach(function (l) {
            var keys = Object.keys(l);
            if (keys.includes('feature') && !feats.includes(l.feature)) {
                feats.push(l.feature)
            }
        });
    }
    if (layerControl != null && typeof (layerControl) == 'object') {
        layerControl['_layers'].forEach(function (c) {
            Object.values(c.layer._layers).forEach(function (l) {
                var keys = Object.keys(l);
                if (keys.includes('_layers')) {
                    Object.values(l['_layers']).forEach(function (f) {
                        if (!feats.includes(f.feature)) {
                            feats.push(f.feature)
                        }
                    });
                }
            });
        });
    }
    return feats;
}

//layer groups from names and keywords
function generateLayerGroups({ groups = [[groupName = null, keyword = null]] }) {
    var laygroups = []
    groups.forEach(function (g) {
        laygroups.push({ name: g[0], keyword: g[1], layers: L.layerGroup() });
    });
    laygroups.push({ name: 'Other', keyword: 'Missing', layers: L.layerGroup() });
    return laygroups;
}

function addLayerGroups(mapInput, layerControl, layers, groups, functionOnLoad = null) {
    //type of layers
    var tiles = [];
    var jsons = [];
    var jsonLayers = [];
    layers.forEach(function (l) {
        if (l.match('{z}/{x}/{y}.png') != null) {
            tiles.push(l);
        }
        if (l.match('.json') != null) {
            jsons.push(l);
        }
    });

    //add layerGroups to map
    function addLayers(mapInput, layerGroups, layerControl) {
        var count = 0;
        groups.forEach(function (g) {
            if (g.name != 'Other') {
                if (count == 0) {
                    layerControl.addBaseLayer(g.layers.addTo(mapInput), g.name);
                    count++;
                }
                else {
                    layerControl.addBaseLayer(g.layers, g.name);
                }
            }
            if (g.name == 'Other') {
                g.layers.addTo(mapInput);
            }
        })
    }

    //tile layers to groups
    tiles.forEach(function (t) {
        var match = false;
        groups.forEach(function (g) {
            if (g.name != 'Other') {
                if (t.match(g.keyword) != null) {
                    tileLayer(t, true).addTo(g.layers);
                    match = true;
                }
            }
        });
        if (!match) {
            tileLayer(t, true).addTo(groups[groups.findIndex((element) => element.name == "Other")].layers)
        }
    });

    if (jsons.length == 0) {
        addLayers(mapInput, groups, layerControl);
    } else {
        //json layers to groups
        var jsonInputs = [];
        jsons.forEach((j) => jsonInputs.push(readData(j)));

        //loading JSON data
        $.when.apply(null, jsonInputs).done(function (response) {
            //loading each JSON layer
            $.each(arguments, function (i, row) {
                var status = row[1], data = row[0];
                if (status === 'success') {
                    var layer = data;
                    layer.features.forEach((f) => f.properties.fullName = '(' + f.properties.Label + ') ' + f.properties.Name);
                    jsonLayers.push(layer);
                }
            });
            //adding JSON layers to groups
            jsonLayers.forEach(function (j) {
                var match = false;
                groups.forEach(function (g) {
                    if (g.name != 'Other') {
                        const name = j.name;
                        if (name.match(g.keyword) != null) {
                            jsonLayer(j).addTo(g.layers);
                            match = true;
                        }
                    }
                });
                if (!match) {
                    jsonLayer(j).addTo(groups[groups.findIndex((element) => element.name == "Other")].layers)
                }
            });
            addLayers(mapInput, groups, layerControl);

            if (functionOnLoad != null && typeof (functionOnLoad) == 'function') {
                functionOnLoad();
            }
        });
    }
}

//creating legend
function addLegend() {
    var legend = L.control({ position: 'bottomleft' });
    legend.onAdd = function (map) {

        var div = L.DomUtil.create('div', 'info legend'),
            grades = [1, 2, 3, 4, 5, 6],
            labels = ['Late fifth to early fourth century BCE',
                'Late fourth century BCE',
                'Third century BCE',
                'Second to first century BCE',
                'First to second century CE',
                'Post Antique'];

        for (var i = 0; i < grades.length; i++) {
            div.innerHTML +=
                '<i style="background:' + getColor(grades[i]) + '"></i> ' + labels[i] + '<br>';
        }

        return div;
    };

    //phasing and legend colors
    function getColor(d) {
        return d == "1" ? '#94d1e7' :
            d == "2" ? '#007abc' :
            d == "3" ? '#00a33c' :
            d == "4" ? '#ff871f' :
            d == "5" ? '#ff171F' :
            d == "6" ? '#fdf500' :
                       '#00000000';
    }

    legend.addTo(map);
}

//creating refresh button control
function addRefresh() {
    L.Control.Button = L.Control.extend({
        options: {
            position: 'topright'
        },
        onAdd: function (map) {
            var container = L.DomUtil.create('div', 'leaflet-bar leaflet-control');
            var button = L.DomUtil.create('a', 'leaflet-control-button', container);
            L.DomEvent.disableClickPropagation(button);
            L.DomEvent.on(button, 'click', function () {
                selectFeature(defaultWebID)
            });

            container.id = "leaflet-refresh-container";
            button.id = "leaflet-refresh-button";
            button.title = "Zoom Out to All Monuments";
            button.innerHTML = 'All Monuments';

            return container;
        },
        onRemove: function (map) { },
    });
    var control = new L.Control.Button();
    control.addTo(map);
}

//creating recenter button control
function addRecenterControl() {
    leaflet.Control.Recenter = leaflet.Control.extend({
        options: {
            position: 'topleft',
            title: 'Zoom to Selected Monument'
        },
        _createButton: function (title, className, content, container, context) {
            this.link = leaflet.DomUtil.create('a', className, container);
            this.link.href = '#';
            this.link.title = title;
            this.link.innerHTML = content;

            this.link.setAttribute('role', 'button');
            this.link.setAttribute('aria-label', title);

            L.DomEvent.disableClickPropagation(container);

            L.DomEvent.on(this.link, 'click', function () {
                var webCode;
                var dropdown = document.getElementById(dropdownName);
                var index = dropdown.options.selectedIndex;
                if (dropdown[index].value == defaultWebID) {
                    webCode = defaultWebID;
                } else {
                    webCode = dropdown[index].value;
                }
                zoomToFeature(getAllFeatures(null, control), webCode);
            });

            return this.link;
        },

        onAdd: function (map) {
            var className = 'leaflet-control-zoom-selection', container, content = '';

            container = map.zoomControl._container;

            if (this.options.content) {
                content = this.options.content;
            } else {
                className += ' recenter-icon';
            }

            this._createButton(this.options.title, className, content, container, this);
            this._map.recenter = this;

            return container;
        }
    })
    var zoomTo = new L.Control.Recenter();
    zoomTo.addTo(map);
}

//creating listener for screen width change & update accordingly
function roundWidth() {
    const q = window.innerWidth;
    const tops = Array.from(document.getElementsByClassName('leaflet-top'));
    var topWidth = 10 * tops.length;
    tops.forEach((f) => topWidth += f.clientWidth);
    return q < 750 ? [q + 'px', (q - 40) + 'px', q + 'px', (q - 40) + 'px'] :
           q < 900 ? [405 + 'px', 365 + 'px', (q - 405) + 'px', (q - 405 - topWidth) + 'px'] :
           q < 1050 ? [475 + 'px', 435 + 'px', (q - 475) + 'px', (q - 475 - topWidth) + 'px'] :
           q < 1200 ? [540 + 'px', 500 + 'px', (q - 540) + 'px', (q - 540 - topWidth) + 'px'] :
           q < 1350 ? [600 + 'px', 560 + 'px', (q - 600) + 'px', (q - 600 - topWidth) + 'px'] :
                        [655 + 'px', 615 + 'px', (q - 655) + 'px', (q - 655 - topWidth) + 'px'];
}

function updateWidth() {
    var oldWidth = width;
    var w = roundWidth();
    width = 'width="' + w[1] + '"';
    document.getElementById('map').style.width = w[2];
    document.getElementById('sidebar').style.width = w[0];
    if (document.getElementById(sidebarText)) {
        document.getElementById(sidebarText).innerHTML = document.getElementById(sidebarText).innerHTML.replaceAll(oldWidth, width);
    }
    if (document.getElementById('dropdown-contents')) {
        document.getElementById('dropdown-contents').style.width = w[3];
    }
}

//ajax request for JSON data
function readData(url) {
    return $.ajax({
        url: url,
        dataType: "json",
        success: function (response) { }
    });
}

//function for unique features from JSON input
function uniqueFeatures(features, id, sort = null, sortType = 'Number') {
    var feats = [];
    var ids = [];
    features.forEach(function (f) {
        if (!ids.includes(f.properties[id])) {
            feats.push(f);
            ids.push(f.properties[id])
        }
    });
    if (sort != null) {
        function fixSortKey(input) {
            switch (sortType) {
                case 'Number':
                    var out = input;
                    out = out.split("-")[0];
                    out = out.replace("a", ".2");
                    out = out.replace("b", ".5");
                    return Number(out);
                case 'String':
                    return String(input);
                default:
                    return input;
            }
        }
        feats.sort(function (a, b) {
            var keyA = fixSortKey(a.properties[sort]);
            var keyB = fixSortKey(b.properties[sort]);
            if (keyA < keyB) return -1;
            if (keyA > keyB) return 1;
            return 0;
        });
    }
    return feats;
}

//generating dropdown menu options from JSON inputs
function dropdownOptions(inputs, value, text) {
    var optionsOut = [];
    inputs.forEach((f) => optionsOut.push('<option value="' + f.properties[value] + '">' + f.properties[text] + '</option>'))
    return optionsOut;
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
function updateOutput(updateDiv, desc) {
    //loading text to sidebar
    L.DomUtil.get(updateDiv).innerHTML = descriptions[desc];
    //reset scroll position
    setTimeout(function () {
        resetScroll();
    }, 10);
}

//function to load and format descriptions 
function loadDescriptions() {
    var names = [];
    var texts = [];
    //pulling text description from url
    function readTxt(desc, url) {
        return $.ajax({
            url: url + desc + "/SamoWebsite_" + desc + ".txt",
            dataType: "text",
            success: function (response) { }
        });
    }
    //reading text descriptions for each monument
    var feats = [defaultWebID];
    uniqueFeatures(getAllFeatures(null, control), 'fullName', 'Label').forEach((f) => feats.push(f.properties.WebCode));
    feats.forEach(function (f) {
        texts.push(readTxt(f, url));
        names.push(f);
    });
    //object containing each description and key
    $.when.apply(null, texts).always(function (response) {
        var newTexts = {};
        $.each(arguments, function (i, row) {
            var status = row[1], data = row[0];
            if (status === 'success') {
                newTexts[names[i]] = outText(names[i], url, data, { remove: remove, replace: replace });
            }
        });
        descriptions = newTexts;
        updateProgress();
        updateOutput(sidebarText, defaultWebID);
    });
}

function updateProgress() {
    counter.progress++;
    counter.speed++;
    var id = setInterval(frame, 10);
    function frame() {
        if (counter.pageNumber >= counter.progress * 50) {
            counter.speed--;
            clearInterval(id);
        } else {
            counter.pageNumber += 1 / counter.speed;
        }
    }
    
}