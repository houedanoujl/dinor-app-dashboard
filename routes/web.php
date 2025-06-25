<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\LoginErrorController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return redirect('/admin');
});

Route::get('/dashboard', function () {
    return redirect('/admin');
})->name('dashboard');

// Route pour la PWA
Route::get('/pwa', function () {
    return redirect('/pwa/');
})->name('pwa');

// Route catch-all pour la PWA SPA (doit être en dernier)
Route::get('/pwa/{path?}', function () {
    return response()->file(public_path('pwa/index.html'));
})->where('path', '.*');

// Route pour la page d'erreur de connexion admin
Route::get('/admin/login-error', [LoginErrorController::class, 'show'])->name('admin.login.error');