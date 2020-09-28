function escapeHTML(html) {
  return jQuery('<div>').text(html).html();
}
function emitDetailsTable(d) {
  let emitRow = function(description, content) {
    if (content == '') return '';
    return `
      <tr>
        <td>${escapeHTML(description)}</td>
        <td>${escapeHTML(content)}</td>
      </tr>`;
  };
  let emitLongStringRow = function(description, summary, content) {
    if (content == '') return '';
    return `
      <tr>
        <td>${escapeHTML(description)}</td>
        <td><details><summary>${escapeHTML(summary)}</summary>${escapeHTML(content)}</details></td>
      </tr>`;
  };

  let emitTagsRow = function(description, tags) {
    if (tags.length == 0) return '';
    let badge = function(text) {
      return `
        <a href="#" class="badge badge-primary">${escapeHTML(text)}</a>
      `;
    };
    let badges = tags.map(badge).join('');
    return `
      <tr>
        <td>${escapeHTML(description)}</td>
        <td id="tag-badges">${badges}</td>
      </tr>`;
  };
  let emitMessageRow = function(content) {
    if (content == '') return '';
    return `
      <tr>
        <td colspan="2">${escapeHTML(content)}</td>
      </tr>`;
  };
  let emitCardRow = function(content) {
    if (content == '') return '';
    return `
      <tr>
        <div class="card">
          <div class="card-body" style="line-height:1.5em;">
            ${marked(content)}
          </div>
        </div>
      </tr>`;
  };
  let emitLinkRow = function(description, content) {
    if (content == '') return '';
    return `
      <tr>
        <td>${escapeHTML(description)}</td>
        <td><a target="_blank" href="${escapeHTML(content)}">${escapeHTML(content)}</a></td>
      </tr>`;
  };
  let emitDocsRow = function(description, content) {
    if (content == '') return '';

    let basename = function(path) {
      var lst = path.split('/');
      return lst[lst.length-1];
    };

    let result = '';
    let title = escapeHTML(description);

    result += `<tr><td>${title}</td><td>`;

    result += content.map((doc) => {
      let escaped_doc = escapeHTML(doc);
      return `
        <span style="white-space: nowrap;">
        <a target="_blank" href="${escaped_doc}">
          <img src="./resources/file.svg" alt="" class="file-img">
          ${basename(escaped_doc)}
        </a></span>`;
    }).join('&emsp;');

    result += `</td></tr>`;

    return result;
  };
  let emitInstallCmdRow = function(pkgname) {
    if (pkgname == '') return '';
    let escaped = escapeHTML('satysfi-' + pkgname);
    return `
        <tr>
        <td>Installation</td>
        <td>
        <div id="install-cmd" class="input-group mb-3">
          <input type="text" class="form-control" aria-label="Installation Command" id="installcmd-${escaped}" value="opam install ${escaped} && satyrographos install" readonly>
          <div class="input-group-append">
            <button class="btn btn-outline-secondary" type="button" data-clipboard-target="#installcmd-${escaped}">Copy</button>
          </div>
        </div>
        </td>
        </tr>`;
  };

  let docrows = '';
  if (d.has_docpkg) {
    if (d.documents.length > 0) {
      docrows += emitDocsRow('Document files', d.documents);
    } else {
      docrows += emitMessageRow(`Document package '${d.name}-doc' is available.`);
    }
  }

  return '<table class="table" cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;line-height:1.5em;"><tbody>'
      + emitCardRow(d.description)
      + emitInstallCmdRow(d.name)
      + emitTagsRow('Tags', d.tags)
      + emitRow('Author', d.authors)
      + emitRow('Maintainer', d.maintainer)
      + emitRow('License', d.license)
      + emitLinkRow('Homepage', d.homepage)
      + emitRow('Latest version', d.latest_version)
      + emitRow('Dependencies', d.dependencies)
      + emitLongStringRow('Font files', 'Included file list...', d.fonts.join(', '))
      + docrows
  +'</tbody></table>';
}

$(document).ready(function() {
  // UMD
  (function( factory ) {
    "use strict";

    if ( typeof define === 'function' && define.amd ) {
      // AMD
      define( ['jquery'], function ( $ ) {
        return factory( $, window, document );
      } );
    }
    else if ( typeof exports === 'object' ) {
      // CommonJS
      module.exports = function (root, $) {
        if ( ! root ) {
          root = window;
        }

        if ( ! $ ) {
          $ = typeof window !== 'undefined' ?
            require('jquery') :
            require('jquery')( root );
        }

        return factory( $, root, root.document );
      };
    } else {
      // Browser
      factory( jQuery, window, document );
    }
  }

  (function($, window, document) {
    $.fn.dataTable.render.moment = function(to) {
      return function (d, type, row) {
        if (!d) {
          return type === 'sort' || type === 'type' ? 0 : d;
        }

        // Order and type get a number value from Moment, everything else
        // sees the rendered value
        return moment.unix(d).utc().format(type === 'sort' || type === 'type' ? 'x' : to);
      };
    };
  }));

  var clipboard = new ClipboardJS('.btn');

  var table = $('#main-table').DataTable({
    lengthMenu: [ [50, 100, -1], [50, 100, "All"] ],
    ajax: "./data.json",
    language: {
      "info":           "Showing _START_ to _END_ of _TOTAL_ packages",
      "infoEmpty":      "Showing 0 to 0 of 0 packages",
      "infoFiltered":   "(filtered from _MAX_ total packages)",
      "lengthMenu":     "Show _MENU_ packages",
      "search":         "Search:",
      "zeroRecords":    "No matching packages found"
    },
    columns: [
      {
        className: "details-control",
        orderable: false,
        data:      null,
        defaultContent: "",
        searchable: false
      },
      {
        className: "details-control-sub",
        data: "name",
        render: $.fn.dataTable.render.text()
      },
      {
        className: "details-control-sub",
        data: "synopsis",
        render: $.fn.dataTable.render.text(),
        orderable: false
      },
      {
        className: "details-control-sub",
        data: "last_update",
        render: $.fn.dataTable.render.moment('ll'),
        orderable: true,
        searchable: false
      },
      {
        data: "description",
        visible: false
      },
      {
        data: "tags",
        visible: false
      },
      {
        data: "fonts",
        visible: false
      }
    ],
    order: [[3, 'desc']]
  });

  $.fn.dataTable.ext.errMode = 'none';
  $('#main-table').on('error.dt', function(e, settings, techNote, message) {
    alert('Unfortunately the site is down for a bit of maintenance right now.\nPlease visit later.');
  });

  $('#tag-buttons ul').on('click', 'a.nav-link', function() {
    let keyword = this.text;
    switch (this.text) {
      case 'all':
        keyword = '';
        break;
      case 'class':
        keyword = 'class-';
        break;
      case 'font':
        keyword = 'fonts-';
        break;
    }

    table.search(keyword).draw();
    return false;
  });

  details_switch_func =  function() {
    var tr = $(this).closest('tr');
    var row = table.row(tr);

    if (row.child.isShown()) {
      // This row is already open - close it
      row.child.hide();
      tr.removeClass('shown');
    } else {
      // Open this row
      row.child(emitDetailsTable(row.data()), "no-hover").show();
      tr.addClass('shown');

      $('#tag-badges').on('click', 'a', function() {
        table.search(this.text).draw();
        return false;
      });
    }
  };

  $('#main-table tbody').on('click', 'td.details-control', details_switch_func);
  $('#main-table tbody').on('click', 'td.details-control-sub', details_switch_func);

});

