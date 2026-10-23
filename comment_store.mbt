///|
priv struct NativeComment {
  id : Int
  post : Int
  author : Int
  author_name : String
  content : String
  status : String
  created : Int64
} derive(ToJson, FromJson, Eq)

///|
priv struct CommentEvent {
  schema : Int
  sequence : Int
  previous : String
  action : String
  comment : NativeComment
} derive(ToJson, FromJson)

///|
priv struct CommentRow {
  comment : NativeComment
  revision : String
}

///|
priv struct CommentState {
  sequence : Int
  revision : String
  rows : Array[CommentRow]
  bytes : Int
}

///|
fn comment_text(text : String, maximum : Int) -> Unit raise {
  require_xml_text(text, "Comment")
  if text.trim().is_empty() || @utf8.encode(text).length() > maximum {
    raise InvalidInput("Comment text bound")
  }
}

///|
fn comment_replay(log : AuthoringDirectory) -> CommentState raise {
  let rows : Array[CommentRow] = []
  let mut sequence = 0
  let mut revision = "absent"
  let mut total = 0
  for name in log.names() {
    sequence += 1
    if name != access_name(sequence) {
      raise InvalidInput("Comment log sequence rejected")
    }
    let file = directory_read(log.fd, authoring_name(name))
    if io_is_null(file) != 0 {
      raise InvalidInput("Cannot open comment record")
    }
    if access_private_file(file) != 1 {
      io_close(file) |> ignore
      raise InvalidInput("Comment record must be private")
    }
    let bytes = read_opened_file(file, name, max_bytes=32768)
    total += bytes.length()
    if total > 16777216 {
      raise InvalidInput("Comment log byte limit")
    }
    let value = @json.parse(decode_text(bytes, "Comment event"))
    let fields = strict_json_object(
      value,
      ["schema", "sequence", "previous", "action", "comment"],
      "Comment event",
    )
    strict_json_object(
      fields.get("comment").unwrap(),
      ["id", "post", "author", "author_name", "content", "status", "created"],
      "Comment",
    )
    |> ignore
    let event : CommentEvent = @json.from_json(value)
    let comment = event.comment
    if event.schema != 1 ||
      event.sequence != sequence ||
      event.previous != revision ||
      comment.id < 1 ||
      comment.post < 1 ||
      comment.author < 1 ||
      comment.created < 0 ||
      !["hold", "approved", "spam", "trash"].contains(comment.status) {
      raise InvalidInput("Invalid comment event")
    }
    comment_text(comment.content, 8192)
    comment_text(comment.author_name, 80)
    if comment.author_name.any(c => c.is_control()) {
      raise InvalidInput("Invalid public author label")
    }
    let next = digest_bytes(bytes)
    if event.action == "create" {
      if rows.length() >= 1024 ||
        comment.id != rows.length() + 1 ||
        comment.status != "hold" {
        raise InvalidInput("Invalid comment creation")
      }
      rows.push({ comment, revision: next, })
    } else if event.action == "status" {
      if comment.id > rows.length() {
        raise InvalidInput("Unknown comment")
      }
      let old = rows[comment.id - 1].comment
      if { ..comment, status: old.status, } != old ||
        comment.status == old.status ||
        (old.status == "trash" && comment.status != "hold") {
        raise InvalidInput("Invalid comment transition")
      }
      rows[comment.id - 1] = { comment, revision: next, }
    } else {
      raise InvalidInput("Unknown comment action")
    }
    revision = next
  }
  { sequence, revision, rows, bytes: total, }
}

///|
fn comment_append(
  log : AuthoringDirectory,
  state : CommentState,
  comment : NativeComment,
  action : String,
) -> CommentRow? raise {
  if action == "create" {
    if comment.id != state.rows.length() + 1 ||
      state.rows.length() >= 1024 ||
      comment.status != "hold" {
      raise InvalidInput("Invalid comment creation")
    }
  } else if action == "status" {
    if comment.id < 1 || comment.id > state.rows.length() {
      raise InvalidInput("Unknown comment")
    }
    let old = state.rows[comment.id - 1].comment
    if { ..comment, status: old.status, } != old ||
      comment.status == old.status ||
      !["hold", "approved", "spam", "trash"].contains(comment.status) ||
      (old.status == "trash" && comment.status != "hold") {
      raise InvalidInput("Invalid comment transition")
    }
  } else {
    raise InvalidInput("Unknown comment action")
  }
  if state.sequence >= 4096 {
    return None
  }
  let event : CommentEvent = {
    schema: 1,
    sequence: state.sequence + 1,
    previous: state.revision,
    action,
    comment,
  }
  let bytes = @utf8.encode(ToJson::to_json(event).stringify() + "\n")
  if bytes.length() > 32768 || state.bytes + bytes.length() > 16777216 {
    return None
  }
  log.write_new(access_name(event.sequence), bytes, private_mode=true)
  Some({ comment, revision: digest_bytes(bytes), })
}

///|
fn comment_open(
  input : String,
  content : AuthoringDirectory,
  create? : Bool = false,
) -> AuthoringDirectory? raise {
  if path_kind(input + "/.moonpress-comments") == 0 {
    if !create {
      return None
    }
    prepare_authoring_vault(input, ".moonpress-comments") |> ignore
  }
  let log = open_authoring_subdirectory(input, ".moonpress-comments")
  errdefer directory_close(log.fd)
  require_same_authoring_site(content, log)
  Some(log)
}
