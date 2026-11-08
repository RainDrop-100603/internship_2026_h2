projection;
strict ( 2 );
use draft;

define behavior for ZC_PS_PROJECT_YJ alias Project
{
  use create;
  use update;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
}