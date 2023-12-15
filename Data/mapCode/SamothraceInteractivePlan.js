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
    shpLayers = ['https://cdn.rawgit.com/jagingrich/samo_website/main/Data/mapFeatures/SamoWeb_RestoredStatePlan_Overlay.shp',
        'https://cdn.rawgit.com/jagingrich/samo_website/main/Data/mapFeatures/SamoWeb_ActualStatePlan_Overlay.shp'];

    dropdownName = 'dropdown-contents';
    //setting description creation vars
    url = 'https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapDescriptions/';
    defaultWebID = '(0)Introduction';
    dropdownDefault = ['<option value="' + defaultWebID + '" disabled selected hidden>Select Monument</option>',
    '<option value="' + defaultWebID + '">About: Interactive Plan</option>'];
    //remove = ['JAG_UNEDITED', 'Glennon'];
    //replace = [['Bibliography:', 'Bibliography: Selected Bibliography']];

    //setting text format parameters
    txt.defaultOptions = {fontSize: '14px'};
    txt.remove = ['JAG_UNEDITED', 'Glennon'];
    txt.replace = {key: 'Bibliography:', replacement: 'Bibliography: Selected Bibliography'};
    txt.imageCode = 'Caption';
    txt.footer = ['---', 'Dates provided in the legend based on interpretations by Karl Lehmann and Phyllis Williams Lehmann', 'Plan date: 2021 - 2022'];
    txt.addCategory('Title', {fontSize: '30px', fontWeight: 'bold'});
    txt.addCategory('Monument', {fontSize: '30px', fontWeight: 'bold'});
    txt.addCategory('Header', {fontSize: '24px', fontWeight: 'bold'});
    txt.addCategory('Subheader', {fontWeight: 'bold'});
    txt.addCategory('Part', {fontWeight: 'bold'});
    txt.addCategory('Bibliography', {fontSize: '18px', fontWeight: 'bold'}, {fontSize: '11px', textIndent: '-36px', paddingLeft: '36px'});
    txt.addCategory('Date', {fontSize: '11px'});
    txt.addCategory('Material', {fontSize: '11px'});
    txt.addCategory('Location', {fontSize: '11px'});
    txt.addCategory('Caption', {fontSize: '11px'});
    txt.addCategory('_footer', {fontSize: '10px'});
    txt.addCategory('_default', {}, {}, false);
    txt.addCategory('_space', {height: '20px'}, {}, false);
    txt._onLoad = function () {
        updateProgress(tileLayers.length + shpFiles.length + 1);
        updateOutput(sidebarText, defaultWebID);
        updateWidth(); //updating window width
    }
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
    zoomToFeature(getAllFeatures(control), webCode);
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
    updateWidth();
    
    //update dropdown
    if (document.getElementById(dropdownName)) {
        var dropdown = document.getElementById(dropdownName);
        dropdown.value = webID;
    }
}

//finding all features in map
function getAllFeatures(inputs, leaflet = false) {
    var feats = [];
    function checkLayers(obj, out) {
        if (Object.keys(obj).includes('_layers')) {
            Object.values(obj._layers).forEach(function (f) {
                if (Object.keys(f).includes('feature') && !out.includes(f.feature)) {
                    if (leaflet) {
                        out.push(f);
                    } else {
                        out.push(f.feature);
                    }                            
                }
            });
        }
    }
    function checkInputs(obj) {
        if (Array.isArray(obj._layers)){
            obj._layers.forEach((l) => {
                Object.values(l.layer._layers).forEach(function (s) {
                    checkLayers(s, feats);
                });
            });
        } else if (typeof (obj) == 'object') {
            checkLayers(obj, feats);
        }
    }
    if (Array.isArray(inputs)){
        inputs.forEach((i) => {
            checkInputs(i);
        });
    } else if (typeof (inputs) == 'object') {
        checkInputs(inputs);
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
    var shps = [];
    layers.forEach(function (l) {
        if (typeof (l) == 'string' && l.match('{z}/{x}/{y}.png') != null) {
            tiles.push(l);
        }
        if (typeof (l) == 'object' && l.type == "FeatureCollection") {
            shps.push(l);
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
        layersCount++;
        updateProgress(tileLayers.length + shpFiles.length + 1);
    });

    //shp layers to groups
    shps.forEach(function (s) {
        var match = false;
        groups.forEach(function (g) {
            if (g.name != 'Other') {
                if (s.name.match(g.keyword) != null) {
                    jsonLayer(s).addTo(g.layers);
                    match = true;
                }
            }
        });
        if (!match) {
            jsonLayer(s).addTo(groups[groups.findIndex((element) => element.name == "Other")].layers)
        }
        layersCount++;
        updateProgress(tileLayers.length + shpFiles.length + 1);
    });
    addLayers(mapInput, groups, layerControl);

    if (functionOnLoad != null && typeof (functionOnLoad) == 'function') {
        functionOnLoad();
    }
}

//ajax request for SHPfile data
function readSHPs(url) {
    url = url.replaceAll('.shp', '');
    $.ajax({
        url: url + '.shp',
        type: "head",
        success: function () {
            shp(url).then(function (out) {
                out.name = url.split('/')[url.split('/').length - 1];
                out.features.forEach((f) => f.properties.fullName = '(' + f.properties.Label + ') ' + f.properties.Name);
                shpFiles.push(out);
                layerCounter.iteration++;
            });
        },
        error: function () {
            layerCounter.iteration++;
        }
    });
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
                zoomToFeature(getAllFeatures(control), webCode);
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
    if (window.innerWidth < window.innerHeight) {
        return [q, q - 40, q, q - 40, 'portrait'];
    }
    else {
        return q < 750 ? [q, q - 40, q, q - 40, 'landscape'] :
            q < 900 ? [405, 365, q - 405, q - 405 - topWidth, 'landscape'] :
            q < 1050 ? [475, 435, q - 475, q - 475 - topWidth, 'landscape'] :
            q < 1200 ? [540, 500, q - 540, q - 540 - topWidth, 'landscape'] :
            q < 1350 ? [600, 560, q - 600, q - 600 - topWidth, 'landscape'] :
                        [655, 615, q - 655, q - 655 - topWidth, 'landscape'];
    }
}

function updateWidth() {
    var oldWidth = width;
    var w = roundWidth();
    width = 'width="' + w[1] + 'px"';
    document.getElementById('map').style.width = w[2] + 'px';
    document.getElementById('sidebar').style.width = w[0] + 'px';
    if (w[4] == 'portrait') {
        document.getElementById('sidebar').style.boxShadow = 'none';
        document.getElementById('sidebar').style.webkitBorderRadius = 0;
        document.getElementById('sidebar').style.borderRadius = 0;
    } else {
        document.getElementById('sidebar').style.boxShadow = '0 1px 7px rgba(0, 0, 0, 0.65)';
        document.getElementById('sidebar').style.webkitBorderRadius = '4px';
        document.getElementById('sidebar').style.borderRadius = '4px';
    }
    if (document.getElementById(sidebarText)) {
        Array.from(document.getElementsByClassName('image')).forEach((i) => {
            i.style.width = w[1] + 'px';
        });
    }
    if (document.getElementById('dropdown-contents')) {
        document.getElementById('dropdown-contents').style.width = w[3] + 'px';
        if (w[4] == 'portrait') {
            document.getElementById('dropdown-contents').style.left = '20px';
            document.getElementById('sidebar-content').style.paddingTop = '50px';
        } else {
            document.getElementById('dropdown-contents').style.left = '54px';
            document.getElementById('sidebar-content').style.paddingTop = '0px';
        }
    }
}

//function for unique features from JSON input
function uniqueFeatures(features, id, sort = null, sortType = 'Number', _return = 'All') {
    var feats = [];
    var ids = [];
    features.forEach(function (f) {
        if (Object.keys(f.properties).includes(id) && !ids.includes(f.properties[id])) {
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
    if (_return == 'All') {
        return feats;
    } else {
        out = [];
        feats.forEach((f) => {
            if(Object.keys(f.properties).includes(_return)) {
                out.push(f.properties[_return]);
            }
        });
        return out;
    }
}

//generating dropdown menu options from JSON inputs
function dropdownOptions(inputs, value, text) {
    var optionsOut = [];
    inputs.forEach((f) => optionsOut.push('<option value="' + f.properties[value] + '">' + f.properties[text] + '</option>'))
    return optionsOut;
}

//html formating for text strings
//formatting methods
const formatText = {
    categories: {},
    defaultOptions: {},
    options: {},
    texts: {},
    count: {total: 0, outOf: null, counting: false},
    remove: [],
    replace: [],
    header: null,
    footer: null,
    addCategory(_class, options = {}, setOptions = {}, resetOptions = true){
        newDiv = document.createElement('div');
        newDiv.value = _class;
        //default options
        Object.entries(this.defaultOptions).forEach((o) => {
            newDiv.style[o[0]] = o[1];
        });
        //applying div formatting for class
        Object.entries(options).forEach((o) => {
            newDiv.style[o[0]] = o[1];
        });
        //set div class
        this.categories[_class] = {cat: newDiv, setOptions: setOptions, resetOptions: resetOptions};
    },
    addDiv(_class, innerHTML = null, src = null){
        var cat;
        if (this.categories[_class]) {
            cat = this.categories[_class];
        } else {
            cat = this.categories['_default'];
        }
        var out = cat.cat.cloneNode(true);
        //resetting div formatting if true
        if(cat.resetOptions) {
            this.options = {};
        }
        //updating div formatting
        Object.entries(this.options).forEach((o) => {
            out.style[o[0]] = o[1];
        });
        //setting formatting for next div if present
        if(Object.keys(cat.setOptions).length != 0) {
            this.options = cat.setOptions;
        }
        //adding text
        if (innerHTML != null) {
            out.innerHTML = innerHTML;
        }
        //adding an image, if src is provided
        if (src != null) {
            container = document.createElement('div');
            imgDiv = document.createElement('img');
            imgDiv.src = src;
            imgDiv.className = 'image';
            container.appendChild(imgDiv);
            container.appendChild(out);
            return container;
        } else {
            return out;
        }
        
    },
    pullTextAndFormat(desc, url){
        const parent = this;
        $.ajax({
            url: url,
            dataType: "text"
        }).then(function(response) {
            //splitting and cleaning text
            out = response.split(/\r\n|\r|\n/); //split on line breaks
            //removing lines based on input remove keywords
            if (Array.isArray(parent.remove)){
                parent.remove.forEach((r) => {
                    out = out.filter(x => x.match(r) == null);
                });
            } else if (typeof (parent.remove) == 'string') {
                out = out.filter(x => x.match(parent.remove) == null);
            }
            //replacing lines based on input replace keywords and replacement lines
            if (Array.isArray(parent.replace)){
                parent.replace.forEach((r) => {
                    out.forEach((item, i) => { if (item.match(r.key) != null) out[i] = r.replacement; });
                });
            } else if (typeof (parent.replace) == 'object') {
                out.forEach((item, i) => { if (item.match(parent.replace.key) != null) out[i] = parent.replace.replacement; });
            }
            //generating linetype codes from line headers
            var capCount = 1;
            out.forEach((item, i) => {
                //splitting off code
                var code = item.split(' ')[0];
                if (code.match(":") != null) {
                    newLine = {Code: code.replace(':', ''), Text: item.replace(code, '').trim()};
                    //code case for images
                    if (Array.isArray(parent.imageCode)){ //multiple image codes
                        parent.imageCode.forEach((r) => {
                            if (newLine.Code == r) {
                                newLine.src = url.replace('.txt', '_Image' + capCount + '.jpg');
                                capCount++;
                            }
                        });
                    } else if (typeof (parent.imageCode) == 'string') { //single image code
                        if (newLine.Code == parent.imageCode) {
                            newLine.src = url.replace('.txt', '_Image' + capCount + '.jpg');
                            capCount++;
                        }
                    }
                    out[i] = newLine;
                } else { //defaults: strings vs. empty strings
                    if (item.trim().length === 0) {
                        newLine = {Code: '_space', Text: item.trim()};
                    } else {
                        newLine = {Code: '_default', Text: item.trim()};
                    }
                    out[i] = newLine;
                }
            });
            //removing white space at top and bottom of text
            while(out[0].Code == '_space' ) { //space at top
                out.shift();
            }
            //space at bottom
            while(out[(out.length - 1)].Code == '_space' && out[(out.length - 2)].Code == '_space') {
                out.pop();
            }
            //adding header to each text if provided
            if (parent.header != null && parent.header.length > 0){
                var header = [];
                if (Array.isArray(parent.header)){
                    parent.header.forEach((h) => {
                        header.push({Code: '_header', Text: h});
                    });
                } else if (typeof (parent.header) == 'string') {
                    header.push({Code: '_header', Text: parent.header});
                }
                out = [...header, ...out];
            }
            //adding footer to each text if provided
            if (parent.footer != null && parent.footer.length > 0){
                if (Array.isArray(parent.footer)){
                    parent.footer.forEach((f) => {
                        out.push({Code: '_footer', Text: f});
                    });
                } else if (typeof (parent.footer) == 'string') {
                    out.push({Code: '_footer', Text: parent.footer});
                }
            }
            //formatting text lines as html divs
            var outDiv = document.createElement('div');
            //formatting each text output based on text code
            out.slice().forEach((o) => outDiv.appendChild(txt.addDiv(o.Code, o.Text, o.src)) );
            //output
            parent.texts[desc] = {WebCode: desc, Text: out, Div: outDiv, Url: url};
        }).always(function(){
            if (parent.count.counting) {
                parent.newText = parent.newText + 1;
            }
        });
    },
    loadText(inputs) {
        //reading text descriptions for each item in inputs
        if (Array.isArray(inputs)){
            this.count.outOf = inputs.length;
            this.count.counting = true;
            inputs.forEach((f) => {
                this.pullTextAndFormat(f.Description, f.Url);
            });
        } else if (typeof (inputs) == 'object') {
            this.count.outOf = Object.keys(inputs).length;
            this.count.counting = true;
            Object.values(inputs).forEach((f) => {
                this.pullTextAndFormat(f.Description, f.Url);
            });
        }
    },
    _onLoad(){},
    update(text){
        if (this.count.total == this.count.outOf){
            this._onLoad();
            this.count.counting = false;
        }
    },
    newFormat(){
        var newObj = jQuery.extend(true, {}, this);
        Object.defineProperty(newObj, 'newText', {
            get: function() {
                return this.count.total;
            },
            set: function(newProp) {
                this.count.total = newProp;
                this.update(newProp);
            },
            enumerable: true
        });
        newObj.addCategory('_default');
        newObj.addCategory('_space');
        newObj.addCategory('_header');
        newObj.addCategory('_footer');
        return newObj;
    }
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
    if (document.getElementById(updateDiv).firstChild) {
        document.getElementById(updateDiv).firstChild.remove();
    }
    document.getElementById(updateDiv).appendChild(txt.texts[desc].Div.cloneNode(true));
    //reset scroll position
    setTimeout(function () {
        resetScroll();
    }, 10);
}

//updating progress bar as layers/descriptions load
function updateProgress(segments) {
    var id = setInterval(frame, 10);
    var iter = 0;
    function frame() {
        if (iter < 100) {
            counter.progress += 1 / segments;
            iter++;
        } else {
            clearInterval(id);
        }
    }
    
}