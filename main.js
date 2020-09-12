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
          <div class="card-body">
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
    for (const doc of content) {
      let escaped_doc = escapeHTML(doc);
      result += `
        <tr>
          <td>${title}</td>
          <td><a target="_blank" href="${escaped_doc}">${basename(escaped_doc)}</a></td>
        </tr>`;
      title = '';
    }
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
  var last_update = moment.parseZone(d.last_update);
  return '<table class="table" cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;"><tbody>'
      + emitCardRow(d.description)
      + emitInstallCmdRow(d.name)
      + emitTagsRow('Tags', d.tags ? d.tags.split(', ') : [])
      + emitRow('Maintainer', d.maintainer)
      + emitRow('License', d.license)
      + emitLinkRow('Homepage', d.homepage)
      + emitRow('Dependencies', d.dependencies)
      + emitRow('Last update', last_update.format('ll') + ' (' + last_update.fromNow() + ')')
      + emitDocsRow('Documents', d.document)
      + emitMessageRow(d.has_docpackage ? `Document package '${d.name}-doc' is available.` : '')
  +'</tbody></table>';
}

$(document).ready(function() {
  var clipboard = new ClipboardJS('.btn');
  var table = $('#main-table').DataTable({
    lengthMenu: [ [50, 100, -1], [50, 100, "All"] ],
    ajax: "./data.json",
    columns: [
      {
        className: "details-control",
        orderable: false,
        data:      null,
        defaultContent: ""
      },
      {
        data: "name",
        render: $.fn.dataTable.render.text()
      },
      {
        data: "synopsis",
        render: $.fn.dataTable.render.text(),
        orderable: false
      },
      {
        data: "latest_version",
        render: $.fn.dataTable.render.text(),
        orderable: false
      },
      {
        data: "description",
        visible: false
      },
      {
        data: "tags",
        visible: false
      }
    ],
    order: [[1, 'asc']]
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
  });

  $('#main-table tbody').on('click', 'td.details-control', function() {
    var tr = $(this).closest('tr');
    var row = table.row(tr);

    if (row.child.isShown()) {
      // This row is already open - close it
      row.child.hide();
      tr.removeClass('shown');
    } else {
      // Open this row
      row.child(emitDetailsTable(row.data())).show();
      tr.addClass('shown');

      $('#tag-badges').on('click', 'a', function() {
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
      });
    }
  });
});

