import { error, type RequestHandler } from '@sveltejs/kit';

export const prerender = false;

const releaseKey = 'releases/mere-film-studio.dmg';

function releaseHeaders(
  object: GraceReleaseHead,
  version: string,
  sha256: string | undefined
): Headers {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('cache-control', 'no-cache, must-revalidate');
  headers.set('content-disposition', `attachment; filename="Mere-Film-Studio-${version}.dmg"`);
  headers.set('content-length', object.size.toString());
  headers.set('etag', object.httpEtag);
  headers.set('x-release-version', version);
  headers.set('x-content-type-options', 'nosniff');
  if (sha256) headers.set('x-release-sha256', sha256);
  return headers;
}

export const GET: RequestHandler = async ({ platform }) => {
  if (!platform) error(503, 'The release service is unavailable.');

  const object = await platform.env.GRACE_RELEASES.get(releaseKey);
  if (!object) error(404, 'The current GRACE release is not available.');

  return new Response(object.body, {
    headers: releaseHeaders(
      object,
      platform.env.GRACE_RELEASE_VERSION,
      platform.env.GRACE_RELEASE_SHA256
    )
  });
};

export const HEAD: RequestHandler = async ({ platform }) => {
  if (!platform) error(503, 'The release service is unavailable.');

  const object = await platform.env.GRACE_RELEASES.head(releaseKey);
  if (!object) error(404, 'The current GRACE release is not available.');

  return new Response(null, {
    headers: releaseHeaders(
      object,
      platform.env.GRACE_RELEASE_VERSION,
      platform.env.GRACE_RELEASE_SHA256
    )
  });
};
