/// Explicitly chosen by the user, not inferred from a site's HTML.
enum WebsitePlatform {
  wordpress('WordPress'),
  shopify('Shopify'),
  html('HTML');

  const WebsitePlatform(this.label);
  final String label;
}

class FixGuide {
  const FixGuide({required this.location, required this.steps, this.note});
  final String location;
  final List<String> steps;
  final String? note;
}

/// Bundled instructions work offline, including while exploring the sample.
/// IDs match the shared audit findings, so a guide always describes its evidence.
/// Menu paths use plain separators to avoid downloading fallback symbol fonts.
class FixGuides {
  FixGuides._();

  static FixGuide? forFinding(String id, WebsitePlatform platform) =>
      switch (platform) {
        WebsitePlatform.wordpress => _wordpress[id],
        WebsitePlatform.shopify => _shopify[id],
        WebsitePlatform.html => _html[id],
      };

  static bool supports(String id) => _wordpress.containsKey(id);

  static const _wordpress = {
    'Meta title': FixGuide(
      location: 'Page or post editor / Yoast SEO',
      steps: [
        'Open the audited page under Pages or Posts in your WordPress dashboard.',
        'Open the Yoast SEO panel and its Search appearance or Google preview editor. Use the SEO title field, which is separate from the visible page heading.',
        'Write a unique, descriptive title with the main topic near the start. Review any site-name variables that Yoast adds.',
        'Save or update the published page. Clear your site cache if it still serves the old title.',
      ],
      note: 'These metadata instructions use Yoast SEO. If your site uses another SEO plugin, use its equivalent title field; you do not need a second SEO plugin.',
    ),
    'Meta description': FixGuide(
      location: 'Page or post editor / Yoast SEO',
      steps: [
        'Open the audited page under Pages or Posts.',
        'In Yoast SEO, open Search appearance or Google preview and find Meta description.',
        'Write a specific summary of this page and its value to visitors. Use natural language instead of a list of keywords.',
        'Update the page and clear any page cache before rechecking its public URL.',
      ],
      note: 'A post excerpt is not always the meta description. These steps use Yoast SEO; other SEO plugins provide a similar metadata field.',
    ),
    'H1 heading': FixGuide(
      location: 'Page editor / title and page template',
      steps: [
        'Open the audited page in the WordPress editor and check its page title.',
        'Check the page template: most themes render the page title as the main H1. If it is hidden, restore the title block or heading in that template.',
        'Use one clear main heading. If the template already supplies an H1, use H2 for section headings in the content.',
        'Update the page and inspect its published heading structure with a recheck.',
      ],
    ),
    'H2 headings': FixGuide(
      location: 'Page editor / Heading block',
      steps: [
        'Open the page and identify meaningful sections of its content.',
        'Add a Heading block before a section, or select an existing heading.',
        'Choose H2 in the block toolbar or settings. Use descriptive section titles and H3 for subsections.',
        'Update the page and recheck. Add headings where they help readers understand the content.',
      ],
    ),
    'Image SEO': FixGuide(
      location: 'Page editor / Image block / Alternative text',
      steps: [
        'Use the Image SEO evidence to locate each affected image on the audited page.',
        'Select the Image block and open its settings. Find Alternative text (alt text).',
        'Describe the purpose of an informative image in this context. Keep genuinely decorative images marked decorative or with empty alt text.',
        'Update the page. Changing only the Media Library default may not update an image already inserted in an existing page.',
      ],
      note: 'The audit flags empty alt text for review too. Decorative images may correctly have empty alt text; do not add meaningless descriptions just to increase the score.',
    ),
    'Schema markup': FixGuide(
      location: 'Yoast SEO / site representation and page Schema settings',
      steps: [
        'Check whether your SEO plugin or theme already outputs structured data for this page.',
        'In Yoast SEO settings, complete Site representation with the real organization or person details.',
        'Open the page editor and its Yoast Schema settings. Select the page or article type that accurately describes the content.',
        'Update the page and validate the published structured data. Use the theme or a suitable schema tool for types your plugin does not support.',
      ],
      note: 'Schema presence is what the core audit checks. It does not confirm complete markup or eligibility for a Google rich result.',
    ),
    'Indexing directives': FixGuide(
      location: 'Yoast SEO / Advanced; Settings / Reading',
      steps: [
        'First decide whether the audited page is intended to appear in public search results.',
        'For a public page, open its Yoast SEO Advanced settings and allow search engines to show the page in search results.',
        'If the whole public site is excluded, review Settings / Reading / Search engine visibility. Also check any maintenance or privacy plugin.',
        'Update the page and recheck the public URL. Keep intentionally private pages excluded.',
      ],
      note: 'Removing a noindex directive allows indexing; it does not prove that a search engine has indexed the page.',
    ),
    'Mobile viewport': FixGuide(
      location: 'Theme settings or theme header template',
      steps: [
        'Check that the active theme supports responsive layouts and is up to date.',
        'Ask the theme maintainer to inspect the published page’s <head> for a device-width viewport tag.',
        'If the tag is missing or incorrect, correct it in the theme header or supported header setting, rather than the page content editor.',
        'Publish the theme change, check the layout on your phone, and recheck the page.',
      ],
    ),
    'Social sharing': FixGuide(
      location: 'Page editor / Yoast SEO / Social settings',
      steps: [
        'Open the audited page and find its Yoast social appearance or Facebook settings.',
        'Set an accurate social title, description and a suitable share image.',
        'Check that Open Graph output is enabled in your SEO plugin and that the image is publicly accessible.',
        'Update the page, clear its cache and recheck the tags. Social networks can keep a separate cached preview.',
      ],
    ),
  };

  static const _shopify = {
    'Meta title': FixGuide(
      location: 'Shopify admin / content item / Search engine listing',
      steps: [
        'Open the audited product, collection, blog post or page in Shopify admin. Standard pages are under Online Store / Pages.',
        'Find Search engine listing and select its edit action (Edit website SEO).',
        'Update Page title with a specific, readable title for this page.',
        'Save the item and recheck its published storefront URL.',
      ],
      note: 'For the homepage, use Online Store / Preferences / Social sharing image and SEO. The SEO page title is separate from the visible content title.',
    ),
    'Meta description': FixGuide(
      location: 'Shopify admin / content item / Search engine listing',
      steps: [
        'Open the product, collection, blog post or page that matches the audited URL.',
        'Edit its Search engine listing and locate Description or Meta description.',
        'Summarize the page’s specific content and benefit in readable language.',
        'Save the item and recheck the public URL rather than an admin or preview link.',
      ],
      note: 'For the homepage, edit the description under Online Store / Preferences. Search engines may choose different snippet text.',
    ),
    'H1 heading': FixGuide(
      location: 'Content item / Title; online store theme template',
      steps: [
        'Open the relevant product, collection, page or blog post in Shopify admin.',
        'Give the item a descriptive Title. Shopify themes normally use this title as the page H1.',
        'If the H1 is still missing or duplicated, inspect the matching theme template and its title section with your theme maintainer.',
        'Save the item or publish the theme update, then recheck the storefront URL.',
      ],
    ),
    'H2 headings': FixGuide(
      location: 'Content item / rich text editor',
      steps: [
        'Open the product description, page or blog post that contains the audited content.',
        'Write a short heading for each meaningful section.',
        'Use the rich text formatting menu to select Heading 2 for section headings. Keep the main title as the page’s H1.',
        'Save the item and recheck the published page.',
      ],
    ),
    'Image SEO': FixGuide(
      location: 'Product / Media / image / Edit alt text',
      steps: [
        'Match the affected image from the audit to its product, collection or content page.',
        'For a product, open Products, select the item, open its image and choose Edit alt text.',
        'Describe the image’s useful information, then save the alt text. For collection or blog images, use the image’s edit settings.',
        'For images inserted inside page content, edit the image in that content editor. Save and recheck the live page.',
      ],
      note: 'Theme-owned and decorative images may need theme settings instead. Empty alt text is correct for purely decorative images, even when flagged for review.',
    ),
    'Schema markup': FixGuide(
      location: 'Online Store / Themes; installed SEO apps',
      steps: [
        'Check the detected schema evidence and whether your theme or an SEO app already generates it.',
        'Complete the relevant product or business details in Shopify so the generated markup has accurate source data.',
        'If markup is missing or invalid, ask your theme or SEO-app maintainer to correct the structured data in the affected template.',
        'Publish the update, validate the markup, then recheck the same storefront URL.',
      ],
      note: 'Shopify themes can generate product JSON-LD dynamically. A static Organization snippet is not a replacement for complete product markup.',
    ),
    'Indexing directives': FixGuide(
      location: 'Store access settings, SEO app or theme template',
      steps: [
        'Confirm whether this is a public storefront page that should appear in search.',
        'Review storefront password settings and any SEO app that can mark the page noindex.',
        'For a public page, remove the unwanted noindex rule in the responsible app or Liquid template with your theme maintainer.',
        'Publish and recheck. Keep intentionally private pages excluded.',
      ],
      note: 'Robots.txt controls crawling and does not cancel a noindex directive. Passing this check does not confirm Google indexing.',
    ),
    'Mobile viewport': FixGuide(
      location: 'Online Store / Themes / theme layout',
      steps: [
        'Check the live theme’s responsive settings and available updates.',
        'Have your theme maintainer inspect layout/theme.liquid for the viewport tag in <head>.',
        'Correct the existing viewport to include width=device-width, initial-scale=1, or add it if absent.',
        'Preview the updated theme on a narrow screen, publish it, then recheck the live URL.',
      ],
    ),
    'Social sharing': FixGuide(
      location: 'Online Store / Preferences; theme social metadata',
      steps: [
        'Set the default Social sharing image under Online Store / Preferences.',
        'Check the audited item’s title, description and featured image, which themes commonly use for social metadata.',
        'If Open Graph tags are missing, have your theme or SEO-app maintainer inspect the social metadata snippet for the affected template.',
        'Save or publish the changes and recheck. A social network may need to refresh its cached preview separately.',
      ],
    ),
  };

  static const _html = {
    'Meta title': FixGuide(
      location: 'The page’s <head> or server-rendered metadata template',
      steps: [
        'Find the template that renders <title> for this specific URL.',
        'Use the editor below to write a unique, descriptive title.',
        'Replace the existing <title> in <head>, or add it if absent. Keep one title element per page.',
        'Deploy the updated page and clear any cached HTML before rechecking.',
      ],
    ),
    'Meta description': FixGuide(
      location: 'The page’s <head> or server-rendered metadata template',
      steps: [
        'Find the description metadata for this exact page.',
        'Write a concise, page-specific summary in the editor below.',
        'Place the generated meta tag in <head>, replacing the existing description tag instead of duplicating it.',
        'Deploy the change and recheck the public URL.',
      ],
    ),
    'H1 heading': FixGuide(
      location: 'The page’s visible <body> content',
      steps: [
        'Find the main visible title in the page template.',
        'Render that title as an <h1>, for example <h1>A guide to your topic</h1>.',
        'Use one clear main heading, with <h2> and <h3> for the sections below it. Check reusable templates for duplicate main titles.',
        'Deploy the change and recheck the headings.',
      ],
    ),
    'H2 headings': FixGuide(
      location: 'The page’s visible <body> content',
      steps: [
        'Identify the useful sections of the page’s content.',
        'Introduce each section with a descriptive <h2>, such as <h2>Planning your visit</h2>.',
        'Use <h3> for subsections and CSS for visual size. Choose heading levels for structure.',
        'Deploy the change and recheck the same page.',
      ],
    ),
    'Image SEO': FixGuide(
      location: 'The affected <img> elements or image component',
      steps: [
        'Find each image listed in the audit evidence.',
        'Add a context-specific alt attribute to informative images, for example alt="A courtyard with stone steps".',
        'Keep the existing src, dimensions and loading attributes. Use alt="" for purely decorative images.',
        'Deploy the page and review the image results again.',
      ],
      note: 'Empty alt text is flagged for review by this audit. Assess decorative images individually instead of adding text solely to raise the score.',
    ),
    'Schema markup': FixGuide(
      location: 'The page template / application/ld+json script',
      steps: [
        'Choose a schema type that accurately describes the page’s content.',
        'Use the editor below as a starting point, and complete the properties required by the relevant schema and search feature.',
        'Place the JSON-LD script in the page template and reconcile it with existing structured data.',
        'Deploy and validate the markup, then recheck schema detection in MobileSEO.',
      ],
      note: 'The generated snippet is a starting point. Detected schema and valid JSON alone do not guarantee rich-result eligibility.',
    ),
    'Indexing directives': FixGuide(
      location: 'The page’s robots/googlebot metadata and response headers',
      steps: [
        'Confirm that the audited page is intended to appear in public search results.',
        'Find the robots or googlebot meta tag containing noindex or none.',
        'For a public page, remove the unwanted restriction in its template. Also inspect server X-Robots-Tag headers for separate restrictions.',
        'Deploy and recheck the live page. Keep intended exclusions for private content.',
      ],
      note: 'This finding checks HTML directives. Search-engine indexing is separate and is not confirmed by a passing audit.',
    ),
    'Mobile viewport': FixGuide(
      location: 'The page’s <head>',
      steps: [
        'Find the viewport meta tag in the page’s <head>.',
        'Use the device-width viewport snippet below to replace the incorrect tag or add it if absent.',
        'Check the page’s responsive CSS and test its layout on a narrow screen.',
        'Deploy and recheck the public page.',
      ],
    ),
    'Social sharing': FixGuide(
      location: 'The page’s <head> / Open Graph metadata',
      steps: [
        'Prepare an accurate social title, description and public, absolute image URL.',
        'Edit the fields below and copy the generated Open Graph tags.',
        'Update og:title, og:description and og:image in <head>, replacing existing values for this page.',
        'Deploy and recheck. Refresh cached previews separately on the social platform if needed.',
      ],
    ),
  };
}
