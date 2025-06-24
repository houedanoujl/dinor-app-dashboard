<?php

namespace App\Filament\Pages;

use Filament\Forms;
use Filament\Forms\Form;
use Filament\Pages\Page;
use Filament\Actions\Action;
use Filament\Support\Exceptions\Halt;
use Filament\Notifications\Notification;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class ManagePassword extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-key';
    
    protected static string $view = 'filament.pages.manage-password';
    
    protected static ?string $title = 'Gestion du mot de passe';
    
    protected static ?string $navigationGroup = 'Système';
    
    protected static ?int $navigationSort = 99;

    public ?array $data = [];
    
    public function mount(): void
    {
        $this->form->fill();
    }
    
    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Changer le mot de passe')
                    ->description('Modifiez votre mot de passe administrateur pour renforcer la sécurité')
                    ->schema([
                        Forms\Components\TextInput::make('current_password')
                            ->label('Mot de passe actuel')
                            ->password()
                            ->required()
                            ->currentPassword(),
                            
                        Forms\Components\TextInput::make('password')
                            ->label('Nouveau mot de passe')
                            ->password()
                            ->required()
                            ->rule(Password::default())
                            ->confirmed(),
                            
                        Forms\Components\TextInput::make('password_confirmation')
                            ->label('Confirmer le nouveau mot de passe')
                            ->password()
                            ->required(),
                    ])
                    ->columns(1)
            ])
            ->statePath('data');
    }
    
    protected function getFormActions(): array
    {
        return [
            Action::make('updatePassword')
                ->label('Mettre à jour le mot de passe')
                ->color('primary')
                ->submit('updatePassword'),
        ];
    }
    
    public function updatePassword(): void
    {
        try {
            $data = $this->form->getState();
            
            $user = auth()->user();
            
            $user->update([
                'password' => Hash::make($data['password']),
            ]);
            
            Notification::make()
                ->title('Mot de passe mis à jour')
                ->body('Votre mot de passe a été mis à jour avec succès.')
                ->success()
                ->send();
                
            $this->form->fill();
            
        } catch (Halt $exception) {
            return;
        }
    }
    
    public static function canAccess(): bool
    {
        return auth()->check();
    }
}