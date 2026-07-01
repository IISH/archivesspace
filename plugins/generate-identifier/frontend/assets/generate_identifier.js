$(function () {

    let form_id = $('.aspace-record-form');
    let prefix = form_id.attr('id').split('_', 2)[0]; // resource of accession
    let id_0 = $('#' + prefix + '_id_0_');
    let id_1 = $('#' + prefix + '_id_1_');

    function generate_id(data) {

        const url = '/plugins/generate_identifier/generate';
        console.log('url=' + url);
        $.ajax({
            url: url,
            data: data,
            type: "POST",
            success: function (response) {
                let identifier = response['identifier'];
                $(id_1).val(identifier);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                let foutmelding = errorThrown + ' statuscode ' + textStatus;
                console.log(foutmelding);
            }
        });
    }

    function call_api() {
        // Met 'this' weten de via de form wat de id is en action.... dus ook of het gaat om accessions of resources.
        if ($(id_1).val()) {
            console.log('id 2 already set.');
        } else {
            let object_type = $(id_0).val();
            console.log('object_type=' + object_type);
            if ( object_type === 'Z') {
                // Periodiek heeft geen ophoging van een database nummer + 1. Bron komt uit evergreen catalogus.
                $(id_1).removeAttr('readonly');
            } else {
                $(id_1).attr(name='readonly');
                generate_id({object_type: object_type});
            }
        }
    }

    $(id_0).change(function () {
        $(id_1).val('');
        call_api();
    });

    if (id_1) {
        $(id_1).click(function () {
            call_api();
        });
    } else {
        console.warn("No suitable form found with class 'aspace-record-form'");
    }

    call_api(); // On load
})
