"! <p class="shorttext synchronized" lang="en">ADT Resource for handling Tagging Preview</p>
CLASS zcl_abaptags_adt_res_tagprev DEFINITION
  PUBLIC
  INHERITING FROM cl_adt_rest_resource
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS:
      constructor,
      post
        REDEFINITION.
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA:
      tags_dac          TYPE REF TO zcl_abaptags_tags_dac,
      object_refs       TYPE SORTED TABLE OF zabaptags_adt_obj_ref WITH UNIQUE KEY name tadir_type,
      preview_info      TYPE zabaptags_tag_preview_info,
      tags_raw          TYPE zabaptags_tag_data_t,
      tagged_obj_counts TYPE zif_abaptags_ty_global=>ty_tag_counts.

    METHODS: get_content_handler
      RETURNING
        VALUE(content_handler) TYPE REF TO if_adt_rest_content_handler,
      "! <p class="shorttext synchronized" lang="en">Collect object references from request body</p>
      collect_object_refs,
      read_tags_flat,
      fill_tagged_object_info,
      determine_tagged_object_count,
      create_response_data.
ENDCLASS.



CLASS zcl_abaptags_adt_res_tagprev IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).
    tags_dac = zcl_abaptags_tags_dac=>get_instance( ).
  ENDMETHOD.


  METHOD post.
    DATA(content_handler) = get_content_handler( ).
    DATA(binary_data) = request->get_inner_rest_request( )->get_entity( )->get_binary_data( ).

    IF binary_data IS NOT INITIAL.
      request->get_body_data(
        EXPORTING content_handler = content_handler
        IMPORTING data            = preview_info ).
    ENDIF.

    collect_object_refs( ).
    read_tags_flat( ).
    determine_tagged_object_count( ).
    fill_tagged_object_info( ).
    create_response_data( ).

    response->set_body_data(
      content_handler = content_handler
      data            = preview_info ).
  ENDMETHOD.


  METHOD get_content_handler.
    content_handler = cl_adt_rest_cnt_hdl_factory=>get_instance( )->get_handler_for_xml_using_st(
      st_name      = 'ZABAPTAGS_TAG_PREVIEW_INFO'
      root_name    = 'TAG_PREVIEW_INFO'
      content_type = if_rest_media_type=>gc_appl_xml ).
  ENDMETHOD.


  METHOD collect_object_refs.

    LOOP AT preview_info-object_refs ASSIGNING FIELD-SYMBOL(<obj_ref>).
      DATA(obj_ref_int) = CORRESPONDING zabaptags_adt_obj_ref( <obj_ref> ).
      TRY.
          zcl_abaptags_adt_util=>map_uri_to_wb_object(
            EXPORTING uri         = <obj_ref>-uri
            IMPORTING object_name = obj_ref_int-name
                      object_type = DATA(object_type)
                      tadir_type  = obj_ref_int-tadir_type ).
          obj_ref_int-type = COND #( WHEN object_type-subtype_wb IS NOT INITIAL THEN object_type-objtype_tr && '/' && object_type-subtype_wb
                                                                                ELSE object_type-objtype_tr ).
          CONDENSE obj_ref_int-name.
          IF obj_ref_int-name CA ' '.
            DATA(whitespace_off) = find( val = obj_ref_int-name regex = '\s' ).
            IF whitespace_off <> -1.
              obj_ref_int-name = obj_ref_int-name(whitespace_off).
            ENDIF.

            obj_ref_int-uri = zcl_abaptags_adt_util=>get_adt_obj_ref( name = |{ obj_ref_int-name }| wb_type = object_type )-uri.
          ENDIF.
          INSERT obj_ref_int INTO TABLE object_refs.
        CATCH cx_adt_uri_mapping.
      ENDTRY.
      DELETE preview_info-object_refs.
    ENDLOOP.

    CLEAR preview_info.

  ENDMETHOD.


  METHOD read_tags_flat.
    tags_raw = VALUE #(
      ( LINES OF tags_dac->find_tags(
          owner_range = VALUE #(
            ( sign = 'I' option = 'EQ' low = sy-uname )
            ( sign = 'I' option = 'EQ' low = space  ) ) ) )
      ( LINES OF zcl_abaptags_tag_util=>get_shared_tags( abap_true ) ) ).
  ENDMETHOD.


  METHOD determine_tagged_object_count.
    tagged_obj_counts = tags_dac->get_tagged_obj_count( object_refs =  CORRESPONDING #( object_refs ) ).
  ENDMETHOD.


  METHOD fill_tagged_object_info.

    LOOP AT tags_raw ASSIGNING FIELD-SYMBOL(<tag>).
      ASSIGN tagged_obj_counts[ tag_id = <tag>-tag_id ] TO FIELD-SYMBOL(<tag_count>).
      IF sy-subrc = 0.
        <tag>-tagged_object_count = <tag_count>-count.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD create_response_data.
    preview_info-tags = zcl_abaptags_tag_util=>build_hierarchical_tags( tags_raw ).
    preview_info-object_refs = CORRESPONDING #( object_refs ).
  ENDMETHOD.

ENDCLASS.
