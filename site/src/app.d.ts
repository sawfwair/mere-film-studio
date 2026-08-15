declare global {
  interface GraceReleaseObject {
    readonly body: ReadableStream<Uint8Array>;
    readonly httpEtag: string;
    readonly size: number;
    writeHttpMetadata(headers: Headers): void;
  }

  interface GraceReleaseHead {
    readonly httpEtag: string;
    readonly size: number;
    writeHttpMetadata(headers: Headers): void;
  }

  interface GraceReleaseBucket {
    get(key: string): Promise<GraceReleaseObject | null>;
    head(key: string): Promise<GraceReleaseHead | null>;
  }

  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    // interface PageState {}
    interface Platform {
      env: {
        GRACE_RELEASES: GraceReleaseBucket;
        GRACE_RELEASE_SHA256?: string;
        GRACE_RELEASE_VERSION: string;
      };
    }
  }
}

export {};
