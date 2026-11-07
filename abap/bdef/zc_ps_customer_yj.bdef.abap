projection;
strict ( 2 );

define behavior for ZC_PS_CUSTOMER_YJ alias Customer
use draft;
{
  use create;
  use update;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
}
