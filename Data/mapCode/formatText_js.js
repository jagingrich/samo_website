//html formating for text strings
//Jared Gingrich 2023

//create new text reader formatter with formatText.newFormat() before setting parameters

//set formatting categories based on line heads with formatText.addCategory()

//set default options for uncategorized lines/unset styling parameters with formatText.defaultOptions

//set lines to remove/replace based on keywords with formatText.remove and formatText.replace

//set header and footer lines to be added to the top and bottom of each input text block with formatText.header and formatText.footer  

//formatText.texts stores loaded text files from inputs given to formatText.loadText()

//formatText.loadText() loads .txt files from the internet, formats them, and outputs to formatText.texts
//this receives input array of objects with keypairs {Description: string, Url: string}
//where Description is a unique identifier for each .txt file to load
//and Url is a valid url to a .txt file
//successfully loaded and formatted texts are stored in formatText.texts with the given Description

//formatText.addDiv() is used internally to format text lines to html
//but can also be used externally to format existing text to html with valid parameters

//formatText.pullTextAndFormat() is used internally to load a .txt file and format based on given parameters 
//but can also be used externally to load a .txt file, format based on given parameters
//and add them to formatText.texts

//formatText._onLoad specifies what happens when all given inputs to formatText.loadText() have run
//formatText._onLoad can receive a new or existing function 

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
        if(cat.resetOptions) { this.options = {}; }
        //updating div formatting
        Object.entries(this.options).forEach((o) => out.style[o[0]] = o[1] );
        //setting formatting for next div if present
        if(Object.keys(cat.setOptions).length != 0) { this.options = cat.setOptions; }
        //adding text
        if (innerHTML != null) { out.innerHTML = innerHTML; }
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
            while(out[0].Code == '_space' ) { out.shift(); } //space at top
            while(out[(out.length - 1)].Code == '_space') { out.pop(); } //space at bottom
            //adding header to each text if provided
            if (parent.header != null && parent.header.length > 0){
                var header = [];
                if (Array.isArray(parent.header)){
                    parent.header.forEach((h) => {
                        if (h.trim().length === 0) {
                            header.push({Code: '_space', Text: h.trim()});
                        } else {
                            header.push({Code: '_header', Text: h.trim()});
                        }
                    });
                } else if (typeof (parent.header) == 'string') {
                    if (parent.header.trim().length === 0) {
                        header.push({Code: '_space', Text: parent.header.trim()});
                    } else {
                        header.push({Code: '_header', Text: parent.header.trim()});
                    }
                }
                out = [...header, ...out];
            }
            //adding footer to each text if provided
            if (parent.footer != null && parent.footer.length > 0){
                if (Array.isArray(parent.footer)){
                    parent.footer.forEach((f) => {
                        if (f.trim().length === 0) {
                            out.push({Code: '_space', Text: f.trim()});
                        } else {
                            out.push({Code: '_footer', Text: f.trim()});
                        }
                    });
                } else if (typeof (parent.footer) == 'string') {
                    if (parent.footer.trim().length === 0) {
                        out.push({Code: '_space', Text: parent.footer.trim()});
                    } else {
                        out.push({Code: '_footer', Text: parent.footer.trim()});
                    }
                }
            }
            //formatting text lines as html divs
            var outDiv = document.createElement('div');
            //formatting each text output based on text code
            out.slice().forEach((o) => {
                var newChild = txt.addDiv(o.Code, o.Text, o.src);
                if (JSON.stringify(o.Text.substring(0,1)) == JSON.stringify('\t')) {
                    newChild.style.textIndent = '36px';
                }
                outDiv.appendChild(newChild);
            });
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