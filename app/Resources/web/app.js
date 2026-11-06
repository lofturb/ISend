/* ---------------------------------------------------------------------------
   ISend · interfaz web
   ES5 puro (sin sintaxis moderna ni promesas): funciona igual en Chrome,
   Edge, Firefox, Safari moderno y en el Safari de iOS 9.
--------------------------------------------------------------------------- */
(function () {
    'use strict';

    var state = {
        cwd: '/',
        entries: [],
        info: null,
        filter: '',
        allowDelete: true,
        allowUpload: true
    };

    var uploadQueue = [];
    var activeUploads = 0;
    var MAX_ACTIVE = 2;
    var ensuredDirs = {};
    var toastTimer = null;
    var refreshTimer = null;
    var dragDepth = 0;

    /* ----------------------------- Utilidades ----------------------------- */

    function $(id) {
        return document.getElementById(id);
    }

    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) { node.className = className; }
        if (text !== undefined && text !== null) { node.textContent = text; }
        return node;
    }

    function api(path, params) {
        var parts = [];
        if (params) {
            for (var key in params) {
                if (Object.prototype.hasOwnProperty.call(params, key) &&
                    params[key] !== null && params[key] !== undefined) {
                    parts.push(encodeURIComponent(key) + '=' +
                               encodeURIComponent(params[key]));
                }
            }
        }
        return path + (parts.length ? '?' + parts.join('&') : '');
    }

    function formatBytes(bytes) {
        var value = Number(bytes) || 0;
        if (value < 1024) { return value + ' B'; }
        var units = ['KB', 'MB', 'GB', 'TB'];
        var index = -1;
        do {
            value = value / 1024;
            index++;
        } while (value >= 1024 && index < units.length - 1);
        var text = value >= 10
            ? Math.round(value).toString()
            : value.toFixed(1).replace('.', ',');
        return text + ' ' + units[index];
    }

    function formatDate(epoch) {
        var date = new Date((Number(epoch) || 0) * 1000);
        if (isNaN(date.getTime())) { return ''; }
        var months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
        return date.getDate() + ' ' + months[date.getMonth()] + ' ' + date.getFullYear();
    }

    function emojiForKind(kind) {
        if (kind === 'folder') { return '📁'; }
        if (kind === 'image') { return '🖼️'; }
        if (kind === 'video') { return '🎬'; }
        if (kind === 'audio') { return '🎵'; }
        if (kind === 'pdf') { return '📕'; }
        if (kind === 'archive') { return '🗜️'; }
        if (kind === 'text') { return '📄'; }
        return '📦';
    }

    function joinPath(base, name) {
        return base === '/' ? '/' + name : base + '/' + name;
    }

    function toast(message, isError) {
        var node = $('toast');
        node.textContent = message;
        node.className = 'toast show' + (isError ? ' error' : '');
        if (toastTimer) { clearTimeout(toastTimer); }
        toastTimer = setTimeout(function () {
            node.className = 'toast';
        }, 2800);
    }

    function parseError(xhr) {
        try {
            var data = JSON.parse(xhr.responseText);
            if (data && data.error) { return data.error; }
        } catch (ignore) {}
        return 'Error ' + xhr.status;
    }

    /* -------------------------------- API --------------------------------- */

    function request(method, url, body, done) {
        var xhr = new XMLHttpRequest();
        xhr.open(method, url, true);
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) { return; }
            var data = null;
            try {
                data = xhr.responseText ? JSON.parse(xhr.responseText) : null;
            } catch (ignore) { data = null; }

            if (xhr.status >= 200 && xhr.status < 300) {
                done(null, data);
            } else {
                done((data && data.error) || ('Error ' + xhr.status), data);
            }
        };
        xhr.onerror = function () { done('No se pudo conectar con el iPad', null); };
        xhr.ontimeout = function () { done('La operación tardó demasiado', null); };
        xhr.send(body || null);
    }

    function loadInfo() {
        request('GET', '/api/info', null, function (error, info) {
            if (error || !info) { return; }
            state.info = info;
            state.allowDelete = info.allowDelete !== false;
            state.allowUpload = info.allowUpload !== false;

            $('deviceName').textContent = info.device || 'iPad';
            $('version').textContent = info.version || '';
            $('netInfo').textContent = location.host;

            updateFooter();
            updateUploadAvailability();
            document.title = 'ISend · ' + (info.device || 'iPad');
        });
    }

    function updateFooter() {
        var info = state.info;
        if (!info) { return; }
        var uploads = info.uploads || 0;
        var text = uploads === 1 ? '1 archivo' : uploads + ' archivos';
        $('stats').textContent = text + ' · ' + formatBytes(info.bytesIn) + ' recibidos';
    }

    function updateUploadAvailability() {
        var disabled = !state.allowUpload;
        var buttons = ['pickFiles', 'pickPhotos', 'pickFolder', 'fabUpload'];
        for (var i = 0; i < buttons.length; i++) {
            var node = $(buttons[i]);
            if (node) { node.disabled = disabled; }
        }
        setDropzoneState(false);
        $('dropzone').setAttribute('aria-disabled', disabled ? 'true' : 'false');
    }

    function setDropzoneState(dragging) {
        var className = 'card dropzone';
        if (!state.allowUpload) {
            className += ' disabled';
        } else if (dragging) {
            className += ' dragover';
        }
        $('dropzone').className = className;
    }

    function loadList(path) {
        $('loading').hidden = false;
        $('emptyState').hidden = true;

        request('GET', api('/api/list', { path: path }), null, function (error, data) {
            $('loading').hidden = true;
            if (error || !data) {
                toast(error || 'No se pudo leer la carpeta', true);
                if (path !== '/') { loadList('/'); }
                return;
            }

            state.cwd = data.path || path;
            state.entries = data.entries || [];

            if (typeof data.free === 'number') {
                $('freeSpace').textContent = formatBytes(data.free) + ' libres';
            }
            $('destPath').textContent = state.cwd;

            renderCrumbs();
            renderList();
        });
    }

    /* ------------------------------- Pintado ------------------------------ */

    function renderCrumbs() {
        var nav = $('crumbs');
        nav.innerHTML = '';

        var parts = state.cwd.split('/');
        var clean = [];
        for (var i = 0; i < parts.length; i++) {
            if (parts[i]) { clean.push(parts[i]); }
        }

        addCrumb(nav, 'iPad', '/', clean.length === 0);
        var accumulated = '';
        for (var j = 0; j < clean.length; j++) {
            accumulated += '/' + clean[j];
            addCrumb(nav, clean[j], accumulated, j === clean.length - 1);
        }
    }

    function addCrumb(nav, label, path, current) {
        if (nav.children.length > 0) {
            nav.appendChild(el('span', 'crumb-sep', '›'));
        }
        if (current) {
            nav.appendChild(el('span', 'crumb current', label));
            return;
        }
        var button = el('button', 'crumb', label);
        button.type = 'button';
        button.title = path;
        button.onclick = function () { loadList(path); };
        nav.appendChild(button);
    }

    function renderList() {
        var list = $('fileList');
        list.innerHTML = '';

        var filter = state.filter.toLowerCase();
        var visible = 0;

        for (var i = 0; i < state.entries.length; i++) {
            var entry = state.entries[i];
            if (filter && entry.name.toLowerCase().indexOf(filter) === -1) { continue; }
            list.appendChild(buildRow(entry));
            visible++;
        }

        var empty = $('emptyState');
        empty.hidden = visible > 0;

        if (visible === 0) {
            var strong = empty.getElementsByTagName('strong')[0];
            var span = empty.getElementsByTagName('span')[0];
            if (filter) {
                strong.textContent = 'Sin resultados';
                span.textContent = 'Ningún archivo coincide con «' + state.filter + '».';
            } else {
                strong.textContent = 'Esta carpeta está vacía';
                span.textContent = 'Envía archivos desde arriba o crea una carpeta con +.';
            }
        }
    }

    function buildRow(entry) {
        var row = el('li', 'file-row');

        var icon = el('span', 'file-icon ' + (entry.kind || 'other'),
                      emojiForKind(entry.kind));
        icon.setAttribute('aria-hidden', 'true');

        var main = el('div', 'file-main');
        var name = el('button', 'file-name', entry.name);
        name.type = 'button';
        name.title = entry.name;
        name.onclick = function () {
            if (entry.dir) {
                loadList(entry.path);
            } else {
                window.open(api('/api/raw', { path: entry.path }), '_blank');
            }
        };

        var meta = el('div', 'file-meta',
                      entry.dir
                          ? 'Carpeta'
                          : formatBytes(entry.size) + ' · ' + formatDate(entry.mtime));

        main.appendChild(name);
        main.appendChild(meta);

        var actions = el('div', 'file-actions');

        if (!entry.dir) {
            var download = el('a', 'action-btn', '↓');
            download.href = api('/api/download', { path: entry.path });
            download.title = 'Descargar';
            download.setAttribute('download', '');
            actions.appendChild(download);
        }

        var rename = el('button', 'action-btn', '✎');
        rename.type = 'button';
        rename.title = 'Renombrar';
        rename.onclick = function () { renameEntry(entry); };
        actions.appendChild(rename);

        if (state.allowDelete) {
            var remove = el('button', 'action-btn danger', '×');
            remove.type = 'button';
            remove.title = 'Borrar';
            remove.onclick = function () { deleteEntry(entry); };
            actions.appendChild(remove);
        }

        row.appendChild(icon);
        row.appendChild(main);
        row.appendChild(actions);
        return row;
    }

    /* ------------------------------ Acciones ------------------------------ */

    function renameEntry(entry) {
        var name = window.prompt('Nuevo nombre para «' + entry.name + '»', entry.name);
        if (!name || name === entry.name) { return; }

        request('POST', api('/api/rename', { path: entry.path, name: name }), null,
                function (error) {
            if (error) { toast(error, true); return; }
            toast('Renombrado');
            loadList(state.cwd);
        });
    }

    function deleteEntry(entry) {
        var question = '¿Borrar «' + entry.name + '»?\n' +
            (entry.dir ? 'Se borrará todo su contenido.' : 'No se puede deshacer.');
        if (!window.confirm(question)) { return; }

        request('POST', api('/api/delete', { path: entry.path }), null,
                function (error) {
            if (error) { toast(error, true); return; }
            toast('Borrado');
            loadList(state.cwd);
            loadInfo();
        });
    }

    function createFolder() {
        var name = window.prompt('Nombre de la nueva carpeta');
        if (!name) { return; }

        request('POST', api('/api/mkdir', { path: state.cwd, name: name }), null,
                function (error) {
            if (error) { toast(error, true); return; }
            toast('Carpeta creada');
            loadList(state.cwd);
        });
    }

    /* ------------------------------- Subidas ------------------------------ */

    function createQueueRow(name) {
        var row = el('div', 'queue-item');
        var head = el('div', 'queue-head');
        var title = el('span', 'queue-name', name);
        var status = el('span', 'queue-status', 'En cola');
        var cancel = el('button', 'queue-cancel', '×');
        cancel.type = 'button';
        cancel.title = 'Cancelar';

        var track = el('div', 'progress');
        var fill = el('i');
        track.appendChild(fill);

        head.appendChild(title);
        head.appendChild(status);
        head.appendChild(cancel);
        row.appendChild(head);
        row.appendChild(track);

        var item = {
            row: row,
            status: status,
            fill: fill,
            cancelButton: cancel,
            xhr: null,
            cancelled: false
        };

        cancel.onclick = function () {
            item.cancelled = true;
            if (item.xhr) {
                item.xhr.abort();
            } else {
                item.status.textContent = 'Cancelado';
                item.row.className = 'queue-item error';
            }
        };

        $('queue').appendChild(row);
        return item;
    }

    function prepareUpload(file, relativePath) {
        var pathParts = (relativePath || file.name).split('/');
        pathParts.pop();

        var item = createQueueRow(file.name);
        item.file = file;

        if (!pathParts.length) {
            enqueue(item, state.cwd);
            return;
        }

        ensureDirs(state.cwd, pathParts, function (directory) {
            if (item.cancelled) { return; }
            enqueue(item, directory);
        });
    }

    function ensureDirs(base, parts, done) {
        var current = base;
        var index = 0;

        function step() {
            if (index >= parts.length) {
                done(current);
                return;
            }
            var name = parts[index];
            var next = joinPath(current, name);

            if (ensuredDirs[next]) {
                current = next;
                index++;
                step();
                return;
            }

            request('POST', api('/api/mkdir', { path: current, name: name }), null,
                    function () {
                ensuredDirs[next] = true;
                current = next;
                index++;
                step();
            });
        }

        step();
    }

    function enqueue(item, directory) {
        item.directory = directory;
        uploadQueue.push(item);
        pump();
    }

    function pump() {
        while (activeUploads < MAX_ACTIVE && uploadQueue.length > 0) {
            var item = uploadQueue.shift();
            if (item.cancelled) { continue; }
            activeUploads++;
            startUpload(item);
        }
    }

    function startUpload(item) {
        item.status.textContent = '0 %';

        var xhr = new XMLHttpRequest();
        item.xhr = xhr;
        xhr.open('PUT', api('/api/upload', {
            path: item.directory,
            name: item.file.name
        }), true);
        xhr.setRequestHeader('Content-Type', 'application/octet-stream');

        xhr.upload.onprogress = function (event) {
            if (!event.lengthComputable) { return; }
            var ratio = Math.min(1, event.loaded / event.total);
            item.fill.style.width = (ratio * 100).toFixed(0) + '%';
            item.status.textContent = Math.round(ratio * 100) + ' %';
        };

        xhr.onload = function () {
            activeUploads--;
            item.xhr = null;

            if (xhr.status >= 200 && xhr.status < 300) {
                item.row.className = 'queue-item done';
                item.status.textContent = 'Listo';
                item.fill.style.width = '100%';
                item.cancelButton.hidden = true;

                setTimeout(function () {
                    if (item.row.parentNode) {
                        item.row.parentNode.removeChild(item.row);
                    }
                }, 2600);

                toast(item.file.name + ' enviado');
                scheduleRefresh(item.directory);
            } else {
                var message = parseError(xhr);
                item.row.className = 'queue-item error';
                item.status.textContent = 'Error';
                item.cancelButton.hidden = true;
                toast(message, true);
            }
            pump();
        };

        xhr.onerror = function () {
            activeUploads--;
            item.xhr = null;
            item.row.className = 'queue-item error';
            item.status.textContent = 'Error de red';
            item.cancelButton.hidden = true;
            toast('No se pudo enviar ' + item.file.name, true);
            pump();
        };

        xhr.onabort = function () {
            activeUploads--;
            item.xhr = null;
            item.row.className = 'queue-item error';
            item.status.textContent = 'Cancelado';
            item.cancelButton.hidden = true;
            pump();
        };

        xhr.send(item.file);
    }

    function scheduleRefresh(directory) {
        if (refreshTimer) { clearTimeout(refreshTimer); }
        refreshTimer = setTimeout(function () {
            if (directory === state.cwd) { loadList(state.cwd); }
            loadInfo();
        }, 350);
    }

    function uploadFromInput(input) {
        var files = input.files;
        if (!files || !files.length) { return; }

        for (var i = 0; i < files.length; i++) {
            var file = files[i];
            var relative = file.webkitRelativePath || file.name;
            prepareUpload(file, relative);
        }
        input.value = '';
    }

    /* --------------------------- Arrastrar y soltar ----------------------- */

    function walkEntry(entry, prefix, output, done) {
        if (entry.isFile) {
            entry.file(function (file) {
                output.push({
                    file: file,
                    relativePath: prefix ? prefix + '/' + file.name : file.name
                });
                done();
            }, function () { done(); });
            return;
        }

        if (entry.isDirectory) {
            readAllEntries(entry.createReader(), function (children) {
                var dirPrefix = prefix ? prefix + '/' + entry.name : entry.name;
                var index = 0;

                function next() {
                    if (index >= children.length) {
                        done();
                        return;
                    }
                    walkEntry(children[index++], dirPrefix, output, next);
                }
                next();
            });
            return;
        }

        done();
    }

    function readAllEntries(reader, done) {
        var all = [];

        function readBatch() {
            reader.readEntries(function (batch) {
                if (!batch.length) {
                    done(all);
                    return;
                }
                for (var i = 0; i < batch.length; i++) { all.push(batch[i]); }
                readBatch();
            }, function () { done(all); });
        }

        readBatch();
    }

    function handleDrop(event) {
        if (!state.allowUpload) {
            toast('El iPad tiene desactivadas las subidas.', true);
            return;
        }

        var transfer = event.dataTransfer;
        if (!transfer) { return; }

        var items = transfer.items;
        if (items && items.length && items[0].webkitGetAsEntry) {
            var entries = [];
            for (var i = 0; i < items.length; i++) {
                var entry = items[i].webkitGetAsEntry();
                if (entry) { entries.push(entry); }
            }
            if (entries.length > 0) {
                var output = [];
                var pending = entries.length;

                for (var j = 0; j < entries.length; j++) {
                    walkEntry(entries[j], '', output, function () {
                        pending--;
                        if (pending === 0) {
                            for (var k = 0; k < output.length; k++) {
                                prepareUpload(output[k].file, output[k].relativePath);
                            }
                        }
                    });
                }
                return;
            }
        }

        var files = transfer.files;
        if (!files || !files.length) { return; }
        for (var n = 0; n < files.length; n++) {
            prepareUpload(files[n], files[n].name);
        }
    }

    /* -------------------------------- Eventos ----------------------------- */

    function bindEvents() {
        $('pickFiles').onclick = function () { $('fileInput').click(); };
        $('pickPhotos').onclick = function () { $('photoInput').click(); };
        $('pickFolder').onclick = function () { $('folderInput').click(); };
        $('fabUpload').onclick = function () { $('fileInput').click(); };

        $('fileInput').onchange = function () { uploadFromInput(this); };
        $('photoInput').onchange = function () { uploadFromInput(this); };
        $('folderInput').onchange = function () { uploadFromInput(this); };

        $('refresh').onclick = function () {
            loadList(state.cwd);
            loadInfo();
            toast('Actualizado');
        };

        $('newFolder').onclick = createFolder;

        $('filter').oninput = function () {
            state.filter = this.value || '';
            renderList();
        };

        // El contenedor no es un boton (contiene botones): con teclado se usan
        // los botones de dentro, pero un clic en el hueco libre tambien sube.
        $('dropzone').onclick = function (event) {
            var node = event.target;
            while (node && node !== this) {
                var tag = node.tagName;
                if (tag === 'BUTTON' || tag === 'A' || tag === 'INPUT') { return; }
                node = node.parentNode;
            }
            if (!state.allowUpload) {
                toast('El iPad tiene desactivadas las subidas.', true);
                return;
            }
            $('fileInput').click();
        };

        document.addEventListener('dragenter', function (event) {
            event.preventDefault();
            if (!state.allowUpload) { return; }
            dragDepth++;
            setDropzoneState(true);
        }, false);

        document.addEventListener('dragleave', function (event) {
            event.preventDefault();
            dragDepth--;
            if (dragDepth <= 0) {
                dragDepth = 0;
                setDropzoneState(false);
            }
        }, false);

        document.addEventListener('dragover', function (event) {
            event.preventDefault();
        }, false);

        document.addEventListener('drop', function (event) {
            event.preventDefault();
            dragDepth = 0;
            setDropzoneState(false);
            handleDrop(event);
        }, false);

        window.onbeforeunload = function () {
            if (activeUploads > 0 || uploadQueue.length > 0) {
                return 'Hay transferencias en curso.';
            }
            return null;
        };
    }

    function init() {
        bindEvents();
        loadInfo();
        loadList('/');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, false);
    } else {
        init();
    }
})();
