//// > **Note**: this is a _release candidate_ for v4.0.0 and documentation is still
//// > a work in progress. If you spot an issue with docs or the library, or would
//// > like to get involved, please [open an issue](https://github.com/lustre-labs/lustre/issues/new)
//// > or a pull request.
////
//// Lustre wouldn't be much use as a frontend framework if it didn't provide a
//// way to create HTML elements. This module contains the basic functions
//// necessary to construct and manipulate different HTML elements.
////
//// It is also possible to use Lustre as a HTML templating library, without
//// using its runtime or framework features.
////

// IMPORTS ---------------------------------------------------------------------

import gleam/list
import gleam/string
import gleam/string_builder.{type StringBuilder}
import lustre/attribute.{type Attribute, attribute}
import lustre/internals/vdom.{Element, Text}

// TYPES -----------------------------------------------------------------------

/// The `Element` type is how Lustre represents chunks of HTML. The `msg` type
/// variable is used to represent the types of messages that can be produced from
/// events on the element or its children.
///
/// **Note:** Just because an element _can_ produces messages of a given type,
/// doesn't mean that it _will_! The `msg` type variable is used to represent the
/// potential for messages to be produced, not a guarantee.
///
/// The most basic ways to create elements are:
///
/// - The [`element`](#element) function to construct arbitrary HTML elements.
///   You can also use this render Custom Elements (like those registered as
///   Lustre components).
///
/// - The [`text`](#text) function to turn a Gleam string into a text node.
///
/// - The [`none`](#none) function to render nothing - useful for conditional
///   rendering.
///
/// If you have more complex needs, there are two more-advanced functions:
///
/// - The [`namespaced`](#namespaced) function to create elements in a specific
///   XML namespace. This is useful for SVG or MathML elements, for example.
///
/// - The [`advanced`](#advanced) function to create elements with more control
///   over how the element is rendered when converted to a string. This is
///   necessary because some HTML, SVG, and MathML elements are self-closing or
///   void elements, and Lustre needs to know how to render them correctly!
///
/// For most applications, you'll only need to use the simpler functions; usually
/// the [`text`](#text) and [`none`](#none) functions are enough. This is because
/// Lustre already provides a module with all the standard HTML and SVG elements
/// ready to use in [`lustre/element/html`](./element/html) and
/// [`lustre/element/svg`](./element/svg).
///
pub type Element(msg) =
  vdom.Element(msg)

// CONSTRUCTORS ----------------------------------------------------------------

/// A general function for constructing any kind of element. In most cases you
/// will want to use the [`lustre/element/html`](./element/html) instead but this
/// function is particularly handing when constructing custom elements, either
/// from your own Lustre components or from external JavaScript libraries.
///
/// **Note:** Because Lustre is primarily used to create HTML, this function
/// spcieal-cases the following tags render as
/// [void elements](https://developer.mozilla.org/en-US/docs/Glossary/Void_element):
///
///   - area
///   - base
///   - br
///   - col
///   - embed
///   - hr
///   - img
///   - input
///   - link
///   - meta
///   - param
///   - source
///   - track
///   - wbr
///
///  This will only affect the output of `to_string` and `to_string_builder`!
///  If you need to render any of these tags with children, *or* you want to
///  render some other tag as self-closing or void, use [`advanced`](#advanced)
///  to construct the element instead.
///
pub fn element(
  tag: String,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  case tag {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" -> Element("", tag, attrs, [], False, True)
    _ ->
      Element(
        namespace: "",
        tag: tag,
        attrs: attrs,
        children: children,
        self_closing: False,
        void: False,
      )
  }
}

/// A function for constructing elements in a specific XML namespace. This can
/// be used to construct SVG or MathML elements, for example.
///
pub fn namespaced(
  namespace: String,
  tag: String,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  Element(
    namespace: namespace,
    tag: tag,
    attrs: attrs,
    children: children,
    self_closing: False,
    void: False,
  )
}

/// A function for constructing elements with more control over how the element
/// is rendered when converted to a string. This is necessary because some HTML,
/// SVG, and MathML elements are self-closing or void elements, and Lustre needs
/// to know how to render them correctly!
///
pub fn advanced(
  namespace: String,
  tag: String,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
  self_closing: Bool,
  void: Bool,
) -> Element(msg) {
  Element(tag, namespace, attrs, children, self_closing, void)
}

/// A function for turning a Gleam string into a text node. Gleam doesn't have
/// union types like some other languages you may be familiar with, like TypeScript.
/// Instead, we need a way to take a `String` and turn it into an `Element` somehow:
/// this function is exactly that!
///
pub fn text(content: String) -> Element(msg) {
  Text(content)
}

/// A function for rendering nothing. This is mostly useful for conditional
/// rendering, where you might want to render something only if a certain
/// condition is met.
///
pub fn none() -> Element(msg) {
  Text("")
}

fn escape(escaped: String, content: String) -> String {
  case content {
    "<" <> rest -> escape(escaped <> "&lt;", rest)
    ">" <> rest -> escape(escaped <> "&gt;", rest)
    "&" <> rest -> escape(escaped <> "&amp;", rest)
    "\"" <> rest -> escape(escaped <> "&quot;", rest)
    "'" <> rest -> escape(escaped <> "&#39;", rest)
    _ ->
      case string.pop_grapheme(content) {
        Ok(#(x, xs)) -> escape(escaped <> x, xs)
        Error(_) -> escaped
      }
  }
}

// MANIPULATIONS ---------------------------------------------------------------

/// The `Element` type is parameterised by the type of messages it can produce
/// from events. Sometimes you might end up with a fragment of HTML from another
/// library or module that produces a different type of message: this function lets
/// you map the messages produced from one type to another.
///
/// Think of it like `list.map` or `result.map` but for HTML events!
///
pub fn map(element: Element(a), f: fn(a) -> b) -> Element(b) {
  case element {
    Text(content) -> Text(content)
    Element(namespace, tag, attrs, children, self_closing, void) ->
      Element(
        namespace,
        tag,
        list.map(attrs, attribute.map(_, f)),
        list.map(children, map(_, f)),
        self_closing,
        void,
      )
  }
}

// CONVERSIONS -----------------------------------------------------------------

/// Convert a Lustre `Element` to a string. This is _not_ pretty-printed, so
/// there are no newlines or indentation. If you need to pretty-print an element,
/// reach out on the [Gleam Discord](https://discord.gg/Fm8Pwmy) or
/// [open an issue](https://github.com/lustre-labs/lustre/issues/new) with your
/// use case and we'll see what we can do!
///
pub fn to_string(element: Element(msg)) -> String {
  vdom.element_to_string(element)
}

/// Convert a Lustre `Element` to a `StringBuilder`. This is _not_ pretty-printed,
/// so there are no newlines or indentation. If you need to pretty-print an element,
/// reach out on the [Gleam Discord](https://discord.gg/Fm8Pwmy) or
/// [open an issue](https://github.com/lustre-labs/lustre/issues/new) with your
/// use case and we'll see what we can do!
///
pub fn to_string_builder(element: Element(msg)) -> StringBuilder {
  vdom.element_to_string_builder(element)
}
