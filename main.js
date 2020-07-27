function escapeHTML(html) {
  return jQuery('<div>').text(html).html();
}
function emitDetailsTable(d) {
  let emitRow = function(description, content) {
    if (content == '') return '';
    return `
      <tr>
        <td>${escapeHTML(description)}:</td>
        <td>${escapeHTML(content)}</td>
      </tr>`;
  };
  let emitLinkRow = function(description, content) {
    if (content == '') return '';
    return `
      <tr>
        <td>${escapeHTML(description)}:</td>
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
    let title = escapeHTML(description) + ':';
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
    let escaped = escapeHTML(pkgname);
    return `
        <tr>
        <td>Installation:</td>
        <td>
        <div class="input-group mb-3">
          <input type="text" class="form-control" aria-label="Installation Command" id="installcmd-${escaped}" value="opam install ${escaped}">
          <div class="input-group-append">
            <button class="btn btn-outline-secondary" type="button" data-clipboard-target="#installcmd-${escaped}">Copy</button>
          </div>
        </div>
        </td>
        </tr>`;
  };
  return '<table class="table" cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;"><tbody>'
      + emitInstallCmdRow(d.name)
      + emitRow('Description', d.description)
      + emitRow('Maintainer', d.maintainer)
      + emitRow('License', d.license)
      + emitLinkRow('Homepage', d.homepage)
      + emitRow('Dependencies', d.dependencies)
      + emitDocsRow('Documents', d.document)
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
        data: "type",
        render: $.fn.dataTable.render.text()
      },
      {
        data: "latest_version",
        render: $.fn.dataTable.render.text(),
        orderable: false
      }
    ],
    order: [[1, 'asc']]
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
    }
  });
});

